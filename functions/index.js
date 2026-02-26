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

function getStripeConfig() {
  const cfg = functions.config().stripe || {};
  return {
    secretKey: cfg.secret_key,
    webhookSecret: cfg.webhook_secret,
  };
}

function getWhatsAppConfig() {
  const cfg = functions.config().whatsapp || {};
  return {
    token: cfg.token,
    phoneNumberId: cfg.phone_number_id,
    businessName: cfg.business_name || 'RentDone',
    apiVersion: cfg.api_version || 'v21.0',
    templateName: cfg.template_name || null,
    templateLanguage: cfg.template_language || 'en',
    maxRetries: Number(cfg.max_retries || 3),
    remindersEnabled: cfg.enabled !== 'false',
  };
}

function getCloudinaryConfig() {
  const cfg = functions.config().cloudinary || {};
  return {
    cloudName: cfg.cloud_name,
    apiKey: cfg.api_key,
    apiSecret: cfg.api_secret,
  };
}

function monthKey(date) {
  const m = String(date.getMonth() + 1).padStart(2, '0');
  return `${date.getFullYear()}-${m}`;
}

function previousMonthKey(date = new Date()) {
  const previous = new Date(date.getFullYear(), date.getMonth() - 1, 1);
  return monthKey(previous);
}

function dueDateFor(year, month, dueDay) {
  const lastDay = new Date(year, month, 0).getDate();
  const safeDay = Math.min(Math.max(dueDay || 1, 1), lastDay);
  return new Date(year, month - 1, safeDay, 9, 0, 0);
}

function toDate(value) {
  if (!value) return null;
  if (value.toDate) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function normalizeIndianPhone(value) {
  if (!value) return null;
  const digits = String(value).replace(/\D/g, '');
  if (digits.length === 10) return `91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return digits;
  return null;
}

function buildUpiLink({ upiId, amount, payeeName, note }) {
  const query = new URLSearchParams({
    pa: upiId,
    pn: payeeName,
    am: String(amount),
    cu: 'INR',
    tn: note,
  });
  return `upi://pay?${query.toString()}`;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function deleteQueryInChunks(query, chunkSize = 400) {
  while (true) {
    const snapshot = await query.limit(chunkSize).get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();

    if (snapshot.size < chunkSize) {
      break;
    }
  }
}

async function postWhatsAppMessage({ token, phoneNumberId, apiVersion, payload }) {
  return fetch(
    `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    },
  );
}

async function sendWhatsAppMessage({ to, body, templateParams }) {
  const {
    token,
    phoneNumberId,
    apiVersion,
    templateName,
    templateLanguage,
    maxRetries,
  } = getWhatsAppConfig();
  if (!token || !phoneNumberId) {
    functions.logger.warn(
      'WhatsApp config missing. Set whatsapp.token and whatsapp.phone_number_id.',
    );
    return {
      ok: false,
      status: 0,
      providerMessageId: null,
      errorBody: 'Missing WhatsApp config',
    };
  }

  const payload = templateName
    ? {
      messaging_product: 'whatsapp',
      to,
      type: 'template',
      template: {
        name: templateName,
        language: { code: templateLanguage },
        components: [
          {
            type: 'body',
            parameters: (templateParams || []).map((value) => ({
              type: 'text',
              text: String(value ?? ''),
            })),
          },
        ],
      },
    }
    : {
      messaging_product: 'whatsapp',
      to,
      type: 'text',
      text: { body },
    };

  let attempt = 0;
  while (attempt < Math.max(maxRetries, 1)) {
    attempt += 1;
    const response = await postWhatsAppMessage({
      token,
      phoneNumberId,
      apiVersion,
      payload,
    });

    const raw = await response.text();
    let parsed;
    try {
      parsed = raw ? JSON.parse(raw) : null;
    } catch (_) {
      parsed = null;
    }

    if (response.ok) {
      return {
        ok: true,
        status: response.status,
        providerMessageId: parsed?.messages?.[0]?.id || null,
        errorBody: null,
      };
    }

    const retryable = response.status === 429 || response.status >= 500;
    const errorBody = raw || 'Unknown WhatsApp API error';
    functions.logger.error('WhatsApp send failed', {
      status: response.status,
      body: errorBody,
      to,
      attempt,
    });

    if (!retryable || attempt >= Math.max(maxRetries, 1)) {
      return {
        ok: false,
        status: response.status,
        providerMessageId: null,
        errorBody,
      };
    }

    await sleep(500 * attempt * attempt);
  }

  return {
    ok: false,
    status: 0,
    providerMessageId: null,
    errorBody: 'Unexpected send flow',
  };
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
        ownerId: t.ownerId || null,
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
      let ownerId = p.ownerId || null;
      writer.update(doc.ref, {
        status: 'overdue',
        updatedAt: FieldValue.serverTimestamp(),
      });

      let tenantName = 'Tenant';
      if (p.tenantId) {
        const tenantDoc = await db.collection('tenants').doc(p.tenantId).get();
        if (tenantDoc.exists) {
          const tenantData = tenantDoc.data() || {};
          tenantName = tenantData.fullName || tenantName;
          ownerId = ownerId || tenantData.ownerId || null;
        }
      }

      const messageId = `${doc.id}_overdue`;
      writer.create(db.collection('messages').doc(messageId), {
        type: 'overdue',
        title: 'Rent overdue',
        body: `${tenantName} has not paid for ${p.periodKey}.`,
        severity: 'critical',
        ownerId,
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
    let ownerId = after.ownerId || null;
    if (after.tenantId) {
      const tenantDoc = await db.collection('tenants').doc(after.tenantId).get();
      if (tenantDoc.exists) {
        const tenantData = tenantDoc.data() || {};
        tenantName = tenantData.fullName || tenantName;
        ownerId = ownerId || tenantData.ownerId || null;
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
        ownerId,
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

exports.sendMonthlyRentStatusNotifications = functions.pubsub
  .schedule('15 10 1 * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const period = previousMonthKey(new Date());
    const monthlyRunKey = monthKey(new Date());

    const paymentsSnap = await db
      .collection('payments')
      .where('periodKey', '==', period)
      .get();

    if (paymentsSnap.empty) return;

    const writer = db.bulkWriter();
    writer.onWriteError((err) => {
      if (err.code === 6) return false;
      return true;
    });

    for (const paymentDoc of paymentsSnap.docs) {
      const payment = paymentDoc.data() || {};

      let ownerId = payment.ownerId || null;
      let tenantName = 'Tenant';

      const tenantId = payment.tenantId;
      if (tenantId) {
        const tenantDoc = await db.collection('tenants').doc(tenantId).get();
        if (tenantDoc.exists) {
          const tenantData = tenantDoc.data() || {};
          tenantName = tenantData.fullName || tenantName;
          ownerId = ownerId || tenantData.ownerId || null;
        }
      }

      if (!ownerId) continue;

      const status = String(payment.status || 'pending').toLowerCase();
      const isPaid = status === 'paid' || status === 'success';
      const statusLabel = isPaid ? 'Paid' : 'Not paid';

      const messageId = `${paymentDoc.id}_monthly_status_${monthlyRunKey}`;
      writer.create(db.collection('messages').doc(messageId), {
        type: 'monthly-status',
        title: 'Monthly rent status',
        body: `${tenantName} rent for ${period}: ${statusLabel}.`,
        severity: isPaid ? 'info' : 'warn',
        ownerId,
        tenantId: tenantId || null,
        paymentId: paymentDoc.id,
        periodKey: period,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });
    }

    await writer.close();
  });

exports.sendRentDueWhatsAppReminders = functions.pubsub
  .schedule('0 9,12,15,18,21 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const { businessName, remindersEnabled } = getWhatsAppConfig();
    if (!remindersEnabled) {
      functions.logger.info('WhatsApp reminders are disabled via config.');
      return;
    }

    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

    const dueSnap = await db
      .collection('payments')
      .where('status', '==', 'pending')
      .where('dueDate', '>=', start)
      .where('dueDate', '<', end)
      .get();

    if (dueSnap.empty) return;

    for (const paymentDoc of dueSnap.docs) {
      const payment = paymentDoc.data();
      const reminderRef = db.collection('messages').doc(`${paymentDoc.id}_wa_due`);
      const reminderExists = await reminderRef.get();
      if (reminderExists.exists) continue;

      if (!payment.tenantId) continue;
      const tenantDoc = await db.collection('tenants').doc(payment.tenantId).get();
      if (!tenantDoc.exists) continue;

      const tenant = tenantDoc.data() || {};
      const ownerId = payment.ownerId || tenant.ownerId || null;
      let bankSnippet = '';
      const to = normalizeIndianPhone(tenant.whatsappPhone || tenant.phone);
      const upiId = String(tenant.upiId || '').trim();
      if (!to || !upiId) continue;

      if (ownerId) {
        const ownerProfileDoc = await db
          .collection('ownerPaymentProfiles')
          .doc(ownerId)
          .get();
        if (ownerProfileDoc.exists) {
          const ownerProfile = ownerProfileDoc.data() || {};
          const bankName = ownerProfile.bankName || '';
          const accountHolder = ownerProfile.bankAccountHolderName || '';
          const accountNumber = ownerProfile.bankAccountNumber || '';
          const ifsc = ownerProfile.bankIfsc || '';
          if (bankName && accountHolder && accountNumber && ifsc) {
            bankSnippet =
              `\n\nBank Transfer Details:\n` +
              `Name: ${accountHolder}\n` +
              `Bank: ${bankName}\n` +
              `A/C: ${accountNumber}\n` +
              `IFSC: ${ifsc}`;
          }
        }
      }

      const amount = Number(payment.amount || tenant.rentAmount || 0);
      const period = payment.periodKey || monthKey(now);
      const tenantName = tenant.fullName || 'Tenant';
      const upiLink = buildUpiLink({
        upiId,
        amount,
        payeeName: businessName,
        note: `Rent ${period}`,
      });

      const body =
        `Hi ${tenantName}, your rent for ${period} is due today.\n` +
        `Amount: Rs ${amount}\n` +
        `Pay now: ${upiLink}` +
        bankSnippet;

      const sent = await sendWhatsAppMessage({
        to,
        body,
        templateParams: [tenantName, period, amount, upiLink],
      });
      if (!sent.ok) {
        await db
          .collection('messages')
          .doc(`${paymentDoc.id}_wa_due_failed_${Date.now()}`)
          .set({
            type: 'reminder',
            channel: 'whatsapp',
            title: 'Rent due reminder failed',
            body: `WhatsApp reminder failed for ${to}.`,
            severity: 'warn',
            ownerId,
            tenantId: payment.tenantId,
            paymentId: paymentDoc.id,
            providerStatus: sent.status,
            providerError: sent.errorBody,
            createdAt: FieldValue.serverTimestamp(),
            read: false,
          });
        continue;
      }

      await reminderRef.set({
        type: 'reminder',
        channel: 'whatsapp',
        title: 'Rent due reminder sent',
        body: `WhatsApp reminder sent to ${to} for ${period}.`,
        severity: 'info',
        ownerId,
        tenantId: payment.tenantId,
        paymentId: paymentDoc.id,
        providerMessageId: sent.providerMessageId,
        providerStatus: sent.status,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });
    }
  });

exports.sendTenantPreDueReminders = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const tenantsSnap = await db.collection('tenants').get();
    if (tenantsSnap.empty) {
      return;
    }

    for (const tenantDoc of tenantsSnap.docs) {
      const tenant = tenantDoc.data() || {};
      const tenantId = tenantDoc.id;

      let dueDay = Number(tenant.rentDueDay || 1);
      let monthlyRent = Number(tenant.rentAmount || 0);

      const roomDetailsDoc = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('room_details')
        .doc('current')
        .get();
      if (roomDetailsDoc.exists) {
        const roomDetails = roomDetailsDoc.data() || {};
        dueDay = Number(roomDetails.rentDueDay || dueDay);
        monthlyRent = Number(roomDetails.monthlyRent || monthlyRent);
      }

      if (!Number.isFinite(dueDay) || dueDay < 1 || dueDay > 31) {
        continue;
      }

      const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
      const safeDueDay = Math.min(Math.max(Math.trunc(dueDay), 1), lastDay);
      const dueDate = new Date(now.getFullYear(), now.getMonth(), safeDueDay);
      const daysUntilDue = Math.floor((dueDate.getTime() - today.getTime()) / (24 * 60 * 60 * 1000));

      if (daysUntilDue !== 3) {
        continue;
      }

      const periodKey = monthKey(dueDate);
      const paymentDoc = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('payments')
        .doc(periodKey)
        .get();

      const paymentStatus = String((paymentDoc.data() || {}).status || '').toLowerCase();
      if (paymentDoc.exists && paymentStatus === 'paid') {
        continue;
      }

      const reminderDocId = `${periodKey}_dminus3`;
      const reminderRef = db
        .collection('tenants')
        .doc(tenantId)
        .collection('reminders')
        .doc(reminderDocId);
      const reminderSnapshot = await reminderRef.get();
      if (reminderSnapshot.exists) {
        continue;
      }

      const amount = Number.isFinite(monthlyRent) && monthlyRent > 0 ? monthlyRent : Number(tenant.dueAmount || 0);
      const body =
        `Your rent is due in 3 days (due day ${safeDueDay}).` +
        (amount > 0 ? ` Amount: Rs ${amount}.` : '');

      await reminderRef.set({
        type: 'rent_due_pre_reminder',
        periodKey,
        title: 'Rent Payment Reminder',
        body,
        dueDay: safeDueDay,
        daysBeforeDue: 3,
        status: 'pending',
        tenantId,
        createdAt: FieldValue.serverTimestamp(),
      });

      await db.collection('messages').doc(`${tenantId}_${reminderDocId}`).set({
        type: 'reminder',
        channel: 'inapp',
        title: 'Rent Payment Reminder',
        body,
        severity: 'info',
        ownerId: tenant.ownerId || null,
        tenantId,
        periodKey,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });
    }
  });

// ==========================================================
// PAYMENT INTENT + VERIFICATION
// ==========================================================

exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required',
    );
  }

  const leaseId = data.leaseId;
  const month = Number(data.month);
  const year = Number(data.year);
  const gateway = (data.gateway || 'razorpay').toLowerCase();
  const idempotencyKey = data.idempotencyKey;

  if (!leaseId || !month || !year || !idempotencyKey) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'leaseId, month, year and idempotencyKey are required',
    );
  }

  const leaseDoc = await db.collection('leases').doc(leaseId).get();
  if (!leaseDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Lease not found');
  }

  const lease = leaseDoc.data();
  if (lease.tenantId && lease.tenantId !== context.auth.uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Lease does not belong to tenant',
    );
  }

  if (lease.status && lease.status !== 'active') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Lease is not active',
    );
  }

  const paymentId = `${leaseId}_${year}_${String(month).padStart(2, '0')}`;
  const paymentRef = db.collection('payments').doc(paymentId);
  const transactionRef = db.collection('transactions').doc(idempotencyKey);

  const existingPayment = await paymentRef.get();
  if (existingPayment.exists) {
    const currentStatus = existingPayment.get('status');
    if (currentStatus === 'paid' || currentStatus === 'success') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Payment already completed for this period',
      );
    }
  }

  const existingTransaction = await transactionRef.get();
  if (existingTransaction.exists) {
    const payment = await paymentRef.get();
    return {
      paymentId,
      gateway,
      amount: payment.get('totalAmount') || 0,
      currency: payment.get('currency') || 'INR',
      idempotencyKey,
      orderId: payment.get('razorpayOrderId') || null,
      clientSecret: payment.get('stripeClientSecret') || null,
      keyId: payment.get('razorpayKeyId') || null,
    };
  }

  const baseAmount = Number(lease.rentAmount || 0);
  const lateFeePercentage = Number(lease.lateFeePercentage || 0);
  const dueDate = toDate(lease.dueDate) || new Date();
  const now = new Date();
  const isOverdue = now > dueDate;
  const lateFeeAmount = isOverdue
    ? Math.round(baseAmount * (lateFeePercentage / 100))
    : 0;
  const totalAmount = baseAmount + lateFeeAmount;

  await db.runTransaction(async (t) => {
    const paymentSnap = await t.get(paymentRef);
    if (paymentSnap.exists) {
      const status = paymentSnap.get('status');
      if (status === 'paid' || status === 'success') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Payment already completed for this period',
        );
      }
    }

    t.set(
      paymentRef,
      {
        paymentId,
        leaseId,
        tenantId: lease.tenantId || context.auth.uid,
        ownerId: lease.ownerId || '',
        propertyId: lease.propertyId || '',
        month,
        year,
        baseAmount,
        lateFeeAmount,
        totalAmount,
        status: 'pending',
        gateway,
        currency: lease.currency || 'INR',
        transactionId: idempotencyKey,
        idempotencyKey,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    t.set(transactionRef, {
      transactionId: idempotencyKey,
      paymentId,
      leaseId,
      tenantId: lease.tenantId || context.auth.uid,
      ownerId: lease.ownerId || '',
      amount: totalAmount,
      currency: lease.currency || 'INR',
      status: 'initiated',
      gateway,
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  if (gateway === 'razorpay') {
    const { keyId, keySecret } = getRazorpayConfig();
    if (!keyId || !keySecret) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Razorpay keys not configured',
      );
    }

    const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    const amountInPaise = totalAmount * 100;
    const receipt = paymentId;

    const orderRes = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountInPaise,
        currency: lease.currency || 'INR',
        receipt,
        notes: { paymentId },
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
    await paymentRef.set(
      {
        razorpayOrderId: order.id,
        razorpayKeyId: keyId,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      paymentId,
      gateway: 'razorpay',
      amount: order.amount,
      currency: order.currency,
      idempotencyKey,
      orderId: order.id,
      keyId,
    };
  }

  if (gateway === 'stripe') {
    const { secretKey } = getStripeConfig();
    if (!secretKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Stripe keys not configured',
      );
    }

    throw new functions.https.HttpsError(
      'failed-precondition',
      'Stripe intent creation not configured',
    );
  }

  throw new functions.https.HttpsError(
    'invalid-argument',
    'Unsupported payment gateway',
  );
});

exports.verifyPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required',
    );
  }

  const paymentId = data.paymentId;
  const gateway = (data.gateway || '').toLowerCase();
  const payload = data.payload || {};

  if (!paymentId || !gateway) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'paymentId and gateway are required',
    );
  }

  const paymentRef = db.collection('payments').doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Payment not found');
  }

  const payment = paymentSnap.data();
  const transactionId = payment.transactionId || payload.transactionId;
  if (!transactionId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Transaction not found for payment',
    );
  }

  const transactionRef = db.collection('transactions').doc(transactionId);
  const transactionSnap = await transactionRef.get();
  if (transactionSnap.exists && transactionSnap.get('status') === 'success') {
    return { ok: true };
  }

  if (gateway === 'razorpay') {
    const { keySecret } = getRazorpayConfig();
    if (!keySecret) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Razorpay secret not configured',
      );
    }

    const razorpayOrderId = payload.orderId;
    const razorpayPaymentId = payload.paymentId;
    const razorpaySignature = payload.signature;

    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
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

    await db.runTransaction(async (t) => {
      const txSnap = await t.get(transactionRef);
      if (txSnap.exists && txSnap.get('status') === 'success') return;

      t.set(
        paymentRef,
        {
          status: 'paid',
          method: 'online',
          transactionId: transactionId,
          razorpayOrderId,
          paidAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      t.set(
        transactionRef,
        {
          status: 'success',
          gatewayResponse: {
            razorpayPaymentId,
            razorpayOrderId,
          },
          verificationSignature: razorpaySignature,
          completedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });

    return { ok: true };
  }

  if (gateway === 'stripe') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Stripe verification not configured',
    );
  }

  throw new functions.https.HttpsError(
    'invalid-argument',
    'Unsupported payment gateway',
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

exports.deleteOwnerPropertyCascade = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required',
    );
  }

  const ownerId = context.auth.uid;
  const propertyId = String(data?.propertyId || '').trim();
  if (!propertyId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'propertyId is required',
    );
  }

  const ownerDoc = await db.collection('users').doc(ownerId).get();
  const role = ownerDoc.data()?.role;
  if (role !== 'owner') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only owners can delete properties',
    );
  }

  const propertyRef = db.collection('properties').doc(propertyId);
  const propertyDoc = await propertyRef.get();
  if (!propertyDoc.exists) {
    return { ok: true, deleted: false, reason: 'not-found' };
  }

  const propertyData = propertyDoc.data() || {};
  const propertyOwnerId = String(propertyData.ownerId || '').trim();

  if (propertyOwnerId && propertyOwnerId !== ownerId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Property does not belong to current owner',
    );
  }

  if (!propertyOwnerId) {
    const ownershipProbe = await db
      .collection('tenants')
      .where('propertyId', '==', propertyId)
      .where('ownerId', '==', ownerId)
      .limit(1)
      .get();

    if (ownershipProbe.empty) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Unable to verify property ownership',
      );
    }
  }

  await deleteQueryInChunks(
    db.collection('tenants').where('propertyId', '==', propertyId),
  );

  await deleteQueryInChunks(
    db.collection('payments').where('propertyId', '==', propertyId),
  );

  await deleteQueryInChunks(
    db.collection('leases').where('propertyId', '==', propertyId),
  );

  await propertyRef.delete();

  return { ok: true, deleted: true };
});

exports.linkTenantAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const uid = context.auth.uid;
  const email = String(context.auth.token.email || '').trim();
  const emailLowercase = email.toLowerCase();

  if (!email) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Authenticated tenant must have an email',
    );
  }

  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  const userData = userDoc.data() || {};
  const role = userData.role || null;

  if (!userDoc.exists || !role) {
    await userRef.set(
      {
        uid,
        email,
        emailLowercase,
        role: 'tenant',
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: userData.createdAt || FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } else if (role !== 'tenant') {
    throw new functions.https.HttpsError('permission-denied', 'Only tenant accounts can link tenant profile');
  }

  let tenantRef = db.collection('tenants').doc(uid);
  let tenantDoc = await tenantRef.get();

  if (!tenantDoc.exists) {
    const byAuthUid = await db
      .collection('tenants')
      .where('authUid', '==', uid)
      .limit(1)
      .get();

    if (!byAuthUid.empty) {
      tenantDoc = byAuthUid.docs[0];
      tenantRef = tenantDoc.ref;
    }
  }

  if (!tenantDoc.exists) {
    const byEmailLower = await db
      .collection('tenants')
      .where('emailLowercase', '==', emailLowercase)
      .limit(1)
      .get();

    if (!byEmailLower.empty) {
      tenantDoc = byEmailLower.docs[0];
      tenantRef = tenantDoc.ref;
    }
  }

  if (!tenantDoc.exists) {
    const byEmail = await db
      .collection('tenants')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (!byEmail.empty) {
      tenantDoc = byEmail.docs[0];
      tenantRef = tenantDoc.ref;
    }
  }

  let autoCreatedTenant = false;
  if (!tenantDoc.exists) {
    autoCreatedTenant = true;
    const fallbackName = String(context.auth.token.name || '').trim() || email.split('@')[0] || 'Tenant';
    tenantRef = db.collection('tenants').doc(uid);

    await tenantRef.set(
      {
        authUid: uid,
        email,
        emailLowercase,
        name: fallbackName,
        phoneNumber: String(context.auth.token.phone_number || '').trim(),
        ownerId: '',
        roomNumber: '-',
        dueAmount: 0,
        totalPaid: 0,
        isActive: false,
        onboardingStatus: 'pending_assignment',
        source: 'self_onboarding',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    tenantDoc = await tenantRef.get();
  }

  await db.runTransaction(async (tx) => {
    tx.set(
      tenantRef,
      {
        authUid: uid,
        email,
        emailLowercase,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    tx.set(
      userRef,
      {
        tenantId: tenantRef.id,
        email,
        emailLowercase,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

  return {
    linked: true,
    tenantId: tenantRef.id,
    email,
    autoCreatedTenant,
  };
});

exports.createTenantImageUploadSignature = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const authHeader = req.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing Authorization bearer token' });
      return;
    }

    const idToken = authHeader.replace('Bearer ', '').trim();
    if (!idToken) {
      res.status(401).json({ error: 'Invalid bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const { cloudName, apiKey, apiSecret } = getCloudinaryConfig();
    if (!cloudName || !apiKey || !apiSecret) {
      res.status(500).json({ error: 'Cloudinary config missing on server' });
      return;
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const folder = `tenants/${uid}`;
    const publicId = `tenant_image_${Date.now()}`;
    const toSign = `folder=${folder}&public_id=${publicId}&timestamp=${timestamp}`;
    const signature = crypto
      .createHash('sha1')
      .update(`${toSign}${apiSecret}`)
      .digest('hex');

    res.status(200).json({
      cloudName,
      apiKey,
      timestamp,
      folder,
      publicId,
      signature,
    });
  } catch (error) {
    functions.logger.error('Failed to create Cloudinary upload signature', { error: String(error) });
    res.status(401).json({ error: 'Unauthorized' });
  }
});

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

exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  res.status(501).send('Stripe webhook not configured');
});
