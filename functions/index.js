const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;

function getRazorpayConfig() {
  const cfg = functions.config().razorpay || {};
  return {
    keyId: cfg.key_id,
    keySecret: cfg.key_secret,
    webhookSecret: cfg.webhook_secret,
  };
}

function monthKey(date) {
  const m = String(date.getMonth() + 1).padStart(2, '0');
  return `${date.getFullYear()}-${m}`;
}

function dueDateFor(year, month, dueDay) {
  const lastDay = new Date(year, month, 0).getDate();
  const safeDay = Math.min(Math.max(dueDay || 1, 1), lastDay);
  return new Date(year, month - 1, safeDay, 9, 0, 0);
}

async function sendPushToAll(title, body) {
  const tokensSnap = await db.collection('fcmTokens').get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (!tokens.length) return;
  const chunkSize = 500;
  for (let i = 0; i < tokens.length; i += chunkSize) {
    const batch = tokens.slice(i, i + chunkSize);
    await admin.messaging().sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
    });
  }
}

function verifyWebhookSignature(rawBody, signature, secret) {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');
  return expected === signature;
}

async function getPaymentIdFromPayload(payload) {
  const paymentNotes = payload?.payment?.entity?.notes || {};
  const orderNotes = payload?.order?.entity?.notes || {};
  return (
    paymentNotes.paymentId ||
    paymentNotes.payment_id ||
    orderNotes.paymentId ||
    orderNotes.payment_id ||
    null
  );
}

exports.generateMonthlyPayments = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const now = new Date();
    const period = monthKey(now);
    const year = now.getFullYear();
    const month = now.getMonth() + 1;

    const tenantsSnap = await db
      .collection('tenants')
      .where('isActive', '==', true)
      .get();

    if (tenantsSnap.empty) return;

    const writer = db.bulkWriter();
    writer.onWriteError((err) => {
      // Ignore if payment for the month already exists
      if (err.code === 6) return false;
      return true;
    });

    tenantsSnap.forEach((doc) => {
      const t = doc.data();
      const dueDate = dueDateFor(year, month, t.rentDueDay || 1);
      const paymentId = `${doc.id}_${period}`;

      writer.create(db.collection('payments').doc(paymentId), {
        tenantId: doc.id,
        propertyId: t.propertyId,
        roomId: t.roomId,
        amount: t.rentAmount || 0,
        dueDate,
        periodKey: period,
        status: 'pending',
        method: 'unknown',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    await writer.close();
  });

exports.markOverdueAndNotify = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const overdueSnap = await db
      .collection('payments')
      .where('status', '==', 'pending')
      .where('dueDate', '<', now)
      .get();

    if (overdueSnap.empty) return;

    const writer = db.bulkWriter();
    writer.onWriteError((err) => {
      if (err.code === 6) return false;
      return true;
    });

    for (const doc of overdueSnap.docs) {
      const p = doc.data();
      writer.update(doc.ref, {
        status: 'overdue',
        updatedAt: FieldValue.serverTimestamp(),
      });

      let tenantName = 'Tenant';
      if (p.tenantId) {
        const tenantDoc = await db.collection('tenants').doc(p.tenantId).get();
        if (tenantDoc.exists) {
          tenantName = tenantDoc.data().fullName || tenantName;
        }
      }

      const messageId = `${doc.id}_overdue`;
      writer.create(db.collection('messages').doc(messageId), {
        type: 'overdue',
        title: 'Rent overdue',
        body: `${tenantName} has not paid for ${p.periodKey}.`,
        severity: 'critical',
        tenantId: p.tenantId,
        paymentId: doc.id,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });
    }

    await writer.close();
    await sendPushToAll(
      'Overdue payments',
      `You have ${overdueSnap.size} overdue payment(s).`,
    );
  });

exports.onPaymentPaid = functions.firestore
  .document('payments/{paymentId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status || after.status !== 'paid') return;

    let tenantName = 'Tenant';
    if (after.tenantId) {
      const tenantDoc = await db.collection('tenants').doc(after.tenantId).get();
      if (tenantDoc.exists) {
        tenantName = tenantDoc.data().fullName || tenantName;
      }
    }

    await db
      .collection('messages')
      .doc(`${change.after.id}_paid`)
      .set({
        type: 'receipt',
        title: 'Payment received',
        body: `${tenantName} paid Rs ${after.amount} for ${after.periodKey}.`,
        severity: 'info',
        tenantId: after.tenantId,
        paymentId: change.after.id,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });

    await sendPushToAll(
      'Payment received',
      `${tenantName} paid Rs ${after.amount} for ${after.periodKey}.`,
    );
  });

// ==========================================================
// RAZORPAY INTEGRATION
// ==========================================================

exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required',
    );
  }

  const { keyId, keySecret } = getRazorpayConfig();
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Razorpay keys not configured',
    );
  }

  const amount = Number(data.amount);
  const currency = data.currency || 'INR';
  const paymentId = data.paymentId;
  const receipt = data.receipt || paymentId;

  if (!paymentId || !amount || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'paymentId and amount are required',
    );
  }

  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const orderRes = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount,
      currency,
      receipt,
      notes: {
        paymentId,
      },
    }),
  });

  if (!orderRes.ok) {
    const text = await orderRes.text();
    throw new functions.https.HttpsError(
      'internal',
      `Razorpay order failed: ${text}`,
    );
  }

  const order = await orderRes.json();

  await db.collection('payments').doc(paymentId).set(
    {
      gateway: 'razorpay',
      razorpayOrderId: order.id,
      method: 'online',
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    orderId: order.id,
    amount: order.amount,
    currency: order.currency,
    keyId,
  };
});

exports.confirmRazorpayPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required',
      );
    }

    const { keySecret } = getRazorpayConfig();
    if (!keySecret) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Razorpay secret not configured',
      );
    }

    const paymentId = data.paymentId;
    const razorpayOrderId = data.razorpayOrderId;
    const razorpayPaymentId = data.razorpayPaymentId;
    const razorpaySignature = data.razorpaySignature;

    if (!paymentId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing Razorpay verification data',
      );
    }

    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    if (expected !== razorpaySignature) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Invalid Razorpay signature',
      );
    }

    await db.collection('payments').doc(paymentId).set(
      {
        status: 'paid',
        method: 'online',
        transactionId: razorpayPaymentId,
        razorpayOrderId,
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { ok: true };
  },
);

exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  const { webhookSecret } = getRazorpayConfig();
  if (!webhookSecret) {
    res.status(500).send('Webhook secret not configured');
    return;
  }

  const signature = req.get('X-Razorpay-Signature');
  if (!signature || !verifyWebhookSignature(req.rawBody, signature, webhookSecret)) {
    res.status(401).send('Invalid signature');
    return;
  }

  const event = req.body?.event;
  const payload = req.body?.payload || {};

  if (event === 'payment.captured' || event === 'order.paid') {
    const paymentEntity = payload?.payment?.entity;
    const orderEntity = payload?.order?.entity;
    let paymentId = await getPaymentIdFromPayload(payload);
    const orderId = paymentEntity?.order_id || orderEntity?.id;

    if (!paymentId && orderId) {
      const snap = await db
        .collection('payments')
        .where('razorpayOrderId', '==', orderId)
        .limit(1)
        .get();
      if (!snap.empty) {
        paymentId = snap.docs[0].id;
      }
    }

    if (paymentId) {
      await db.collection('payments').doc(paymentId).set(
        {
          status: 'paid',
          method: 'online',
          transactionId: paymentEntity?.id,
          razorpayOrderId: orderId,
          paidAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  } else if (event === 'payment.failed') {
    const paymentEntity = payload?.payment?.entity;
    const paymentId = await getPaymentIdFromPayload(payload);
    if (paymentId) {
      await db.collection('messages').doc(`${paymentId}_failed`).set({
        type: 'reminder',
        title: 'Payment failed',
        body: `Razorpay payment failed (${paymentEntity?.error_description || 'unknown reason'}).`,
        severity: 'warn',
        paymentId,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });
    }
  }

  res.json({ received: true });
});
