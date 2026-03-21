const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

function parseBool(value, fallback = false) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  return ['1', 'true', 'yes', 'on'].includes(normalized);
}

function getSecurityConfig() {
  const cfg = functions.config().security || {};
  return {
    enforceAppCheck: parseBool(
      cfg.enforce_app_check,
      true,
    ),
    allowedOrigin: String(
      cfg.allowed_origin || process.env.SECURITY_ALLOWED_ORIGIN || '',
    ).trim(),
  };
}

function assertCallableAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required',
    );
  }

  const { enforceAppCheck } = getSecurityConfig();
  if (enforceAppCheck && !context.app) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'App Check token is required',
    );
  }
}

function setCorsHeaders(req, res) {
  const { allowedOrigin } = getSecurityConfig();
  const requestOrigin = String(req.get('Origin') || '').trim();

  if (!allowedOrigin) {
    return;
  }

  if (requestOrigin && requestOrigin === allowedOrigin) {
    res.set('Access-Control-Allow-Origin', requestOrigin);
    res.set('Vary', 'Origin');
  }
}

function safeEqualDigest(expected, received, encoding = 'hex') {
  if (!expected || !received) return false;
  try {
    const a = Buffer.from(String(expected), encoding);
    const b = Buffer.from(String(received), encoding);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  } catch (_) {
    return false;
  }
}

async function verifyHttpAppCheckOrThrow(req) {
  const { enforceAppCheck } = getSecurityConfig();
  if (!enforceAppCheck) return;

  const appCheckToken = String(req.get('X-Firebase-AppCheck') || '').trim();
  if (!appCheckToken) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Missing App Check token',
    );
  }

  await admin.appCheck().verifyToken(appCheckToken);
}

async function assertTenantAccessOrThrow(uid) {
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'User profile not found',
    );
  }

  const role = String(userDoc.data()?.role || '').trim().toLowerCase();
  if (role !== 'tenant') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only tenant users can perform this operation',
    );
  }
}

async function recordWebhookDelivery({ provider, uniqueKey, rawBody }) {
  const safeProvider = String(provider || '').trim().toLowerCase() || 'unknown';
  const keyHash = crypto
    .createHash('sha256')
    .update(String(uniqueKey || ''))
    .digest('hex');
  const payloadHash = crypto
    .createHash('sha256')
    .update(rawBody || '')
    .digest('hex');

  const docId = `${safeProvider}_${keyHash}`;
  try {
    const expiresAt = Timestamp.fromDate(new Date(Date.now() + (7 * 24 * 60 * 60 * 1000)));
    await db.collection('_webhookEvents').doc(docId).create({
      provider: safeProvider,
      uniqueKeyHash: keyHash,
      payloadHash,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
    });
    return true;
  } catch (error) {
    if (error?.code === 6 || String(error?.message || '').toLowerCase().includes('already exists')) {
      return false;
    }
    throw error;
  }
}

function requestIpFromHeaders(req) {
  const forwarded = String(req.get('x-forwarded-for') || '').trim();
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  return String(req.ip || '').trim() || 'unknown';
}

function minuteBucketKey(date = new Date()) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  const h = String(date.getUTCHours()).padStart(2, '0');
  const min = String(date.getUTCMinutes()).padStart(2, '0');
  return `${y}${m}${d}${h}${min}`;
}

async function recordSecuritySignal({
  type,
  channel,
  uid = null,
  ip = 'unknown',
  reason = 'unknown',
  statusCode = 0,
  meta = {},
}) {
  const safeType = String(type || 'unknown').trim().toLowerCase();
  const safeChannel = String(channel || 'unknown').trim().toLowerCase();
  const bucket = minuteBucketKey();
  const docId = `${safeType}_${bucket}`;
  const ref = db.collection('_securitySignals').doc(docId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const currentCount = snap.exists ? Number(snap.data()?.count || 0) : 0;
    const nextCount = currentCount + 1;
    const expiresAt = Timestamp.fromDate(new Date(Date.now() + (7 * 24 * 60 * 60 * 1000)));
    tx.set(ref, {
      type: safeType,
      channel: safeChannel,
      bucket,
      count: nextCount,
      lastUid: uid || null,
      lastIp: ip || 'unknown',
      lastReason: String(reason || 'unknown'),
      lastStatusCode: Number(statusCode) || 0,
      lastMeta: meta || {},
      updatedAt: FieldValue.serverTimestamp(),
      expiresAt,
      ...(snap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
    }, { merge: true });
    return nextCount;
  });

  if (result === 5 || result === 20 || result === 50) {
    await db.collection('_securityAlerts').add({
      type: safeType,
      channel: safeChannel,
      bucket,
      count: result,
      severity: result >= 50 ? 'high' : result >= 20 ? 'medium' : 'low',
      uid: uid || null,
      ip: ip || 'unknown',
      reason: String(reason || 'unknown'),
      statusCode: Number(statusCode) || 0,
      meta: meta || {},
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(new Date(Date.now() + (14 * 24 * 60 * 60 * 1000))),
    });
  }
}

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

function getCashfreeConfig() {
  const cfg = functions.config().cashfree || {};
  return {
    appId: cfg.app_id || process.env.CASHFREE_APP_ID || '',
    secretKey: cfg.secret_key || process.env.CASHFREE_SECRET_KEY || '',
    webhookSecret: cfg.webhook_secret || process.env.CASHFREE_WEBHOOK_SECRET || '',
    isSandbox: (cfg.env || process.env.CASHFREE_ENV || 'production') === 'sandbox',
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
  return safeEqualDigest(expected, signature, 'hex');
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

exports.cleanupExpiredWebhookEvents = functions.pubsub
  .schedule('every 6 hours')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const now = Timestamp.now();
    await deleteQueryInChunks(
      db.collection('_webhookEvents').where('expiresAt', '<=', now),
    );
    await deleteQueryInChunks(
      db.collection('_securitySignals').where('expiresAt', '<=', now),
    );
    await deleteQueryInChunks(
      db.collection('_securityAlerts').where('expiresAt', '<=', now),
    );
    return null;
  });

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
  assertCallableAuth(context);
  await assertTenantAccessOrThrow(context.auth.uid);

  const leaseId = data.leaseId;
  const month = Number(data.month);
  const year = Number(data.year);
  const gateway = (data.gateway || 'cashfree').toLowerCase();
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
      paymentSessionId: payment.get('cashfreeTokenData') || payment.get('cashfreePaymentSessionId') || null,
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

  if (gateway === 'cashfree') {
    const { appId, secretKey, isSandbox } = getCashfreeConfig();
    if (!appId || !secretKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cashfree not configured',
      );
    }

    // Cashfree SDK v2 uses cftoken API
    const cashfreeBaseUrl = isSandbox
      ? 'https://test.cashfree.com'
      : 'https://api.cashfree.com';

    const cashfreeOrderId = `cf_${paymentId}`;
    const orderAmountInRupees = (totalAmount / 100).toFixed(2);

    const tokenResponse = await fetch(`${cashfreeBaseUrl}/api/v2/cftoken/order`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': appId,
        'x-client-secret': secretKey,
      },
      body: JSON.stringify({
        orderId: cashfreeOrderId,
        orderAmount: orderAmountInRupees,
        orderCurrency: currency,
      }),
    });

    if (!tokenResponse.ok) {
      const errText = await tokenResponse.text();
      throw new functions.https.HttpsError(
        'internal',
        `Cashfree token creation failed: ${errText}`,
      );
    }

    const tokenData = await tokenResponse.json();
    if (tokenData.status !== 'OK') {
      throw new functions.https.HttpsError(
        'internal',
        `Cashfree token error: ${tokenData.message || 'Unknown error'}`,
      );
    }
    const cftoken = tokenData.cftoken;

    await db.runTransaction(async (txn) => {
      txn.set(
        paymentRef,
        {
          cashfreeOrderId: cashfreeOrderId,
          cashfreeTokenData: cftoken,
          currency,
          totalAmount,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      txn.set(transactionRef, {
        paymentId,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    return {
      paymentId,
      gateway: 'cashfree',
      amount: totalAmount,
      currency,
      idempotencyKey,
      orderId: cashfreeOrderId,
      paymentSessionId: cftoken,
      keyId: appId,
      clientSecret: null,
    };
  }

  throw new functions.https.HttpsError(
    'invalid-argument',
    'Unsupported payment gateway',
  );
});

exports.verifyPayment = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);
  await assertTenantAccessOrThrow(context.auth.uid);

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
  const callerUid = context.auth.uid;
  const ownsPayment = payment.tenantId === callerUid || payment.ownerId === callerUid;
  if (!ownsPayment) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Payment does not belong to current user',
    );
  }

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

    if (!safeEqualDigest(expected, razorpaySignature, 'hex')) {
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

  if (gateway === 'cashfree') {
    const paymentDoc = await db.collection('payments').doc(paymentId).get();
    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment record not found');
    }

    const cashfreeOrderId = paymentDoc.get('cashfreeOrderId');
    if (!cashfreeOrderId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cashfree order ID not found for this payment',
      );
    }

    const { appId, secretKey, isSandbox } = getCashfreeConfig();
    if (!appId || !secretKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Cashfree not configured');
    }

    const cashfreeBaseUrl = isSandbox
      ? 'https://test.cashfree.com'
      : 'https://api.cashfree.com';

    const orderRes = await fetch(`${cashfreeBaseUrl}/api/v2/orders/${cashfreeOrderId}`, {
      method: 'GET',
      headers: {
        'x-client-id': appId,
        'x-client-secret': secretKey,
      },
    });

    if (!orderRes.ok) {
      const errText = await orderRes.text();
      throw new functions.https.HttpsError('internal', `Cashfree order fetch failed: ${errText}`);
    }

    const orderData = await orderRes.json();
    if (orderData.orderStatus !== 'PAID') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Payment not completed. Status: ${orderData.orderStatus}`,
      );
    }

    const cfTransactionId = orderData.referenceId?.toString() || cashfreeOrderId;

    const now = FieldValue.serverTimestamp();
    await db.collection('payments').doc(paymentId).set(
      {
        status: 'paid',
        method: 'online',
        transactionId: cfTransactionId,
        cashfreeOrderId,
        paidAt: now,
        updatedAt: now,
      },
      { merge: true },
    );

    await db.collection('transactions').add({
      paymentId,
      gateway: 'cashfree',
      status: 'success',
      transactionId: cfTransactionId,
      cashfreeOrderId,
      amount: paymentDoc.get('totalAmount') || 0,
      currency: paymentDoc.get('currency') || 'INR',
      createdAt: now,
      updatedAt: now,
    });

    return { success: true };
  }

  throw new functions.https.HttpsError(
    'invalid-argument',
    'Unsupported payment gateway',
  );
});

// ==========================================================
// OWNER RAZORPAY PAYMENT INTENT + VERIFICATION
// ==========================================================

exports.createOwnerRazorpayPaymentIntent = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  await assertOwnerAccessOrThrow(ownerId);

  const tenantId = String(data?.tenantId || '').trim();
  const propertyId = String(data?.propertyId || '').trim();
  const idempotencyKey = String(data?.idempotencyKey || '').trim();
  const amount = Number(data?.amount || 0);
  const currency = 'INR';

  if (!tenantId || !propertyId || !idempotencyKey || !Number.isInteger(amount) || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'tenantId, propertyId, idempotencyKey and positive integer amount are required',
    );
  }

  if (amount > 5000000) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Amount exceeds allowed maximum',
    );
  }

  const tenantRef = db.collection('tenants').doc(tenantId);
  const propertyRef = db.collection('properties').doc(propertyId);
  const transactionRef = db.collection('transactions').doc(idempotencyKey);

  const [tenantDoc, propertyDoc] = await Promise.all([
    tenantRef.get(),
    propertyRef.get(),
  ]);

  if (!tenantDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Tenant not found');
  }
  if (!propertyDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Property not found');
  }

  const tenantData = tenantDoc.data() || {};
  const propertyData = propertyDoc.data() || {};

  if (String(propertyData.ownerId || '') !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Property does not belong to owner');
  }
  if (String(tenantData.ownerId || '') !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Tenant does not belong to owner');
  }
  if (String(tenantData.propertyId || '') !== propertyId) {
    throw new functions.https.HttpsError('failed-precondition', 'Tenant is not assigned to this property');
  }

  const existingTransaction = await transactionRef.get();
  if (existingTransaction.exists) {
    const existingPaymentId = String(existingTransaction.get('paymentId') || '').trim();
    if (existingPaymentId) {
      const existingPayment = await db.collection('payments').doc(existingPaymentId).get();
      if (existingPayment.exists) {
        return {
          paymentId: existingPaymentId,
          gateway: 'razorpay',
          amountInPaise: Number(existingPayment.get('amountInPaise') || amount * 100),
          currency: String(existingPayment.get('currency') || currency),
          idempotencyKey,
          orderId: existingPayment.get('razorpayOrderId') || null,
          keyId: existingPayment.get('razorpayKeyId') || null,
        };
      }
    }
  }

  const paymentRef = db.collection('payments').doc();
  const paymentId = paymentRef.id;
  const amountInPaise = amount * 100;

  await db.runTransaction(async (txn) => {
    const txSnap = await txn.get(transactionRef);
    if (txSnap.exists) {
      throw new functions.https.HttpsError('already-exists', 'Payment transaction already initialized');
    }

    txn.set(paymentRef, {
      paymentId,
      tenantId,
      ownerId,
      propertyId,
      amount,
      baseAmount: amount,
      paidAmount: 0,
      remainingAmount: amount,
      amountInPaise,
      status: 'pending',
      method: 'Razorpay',
      currency,
      transactionId: idempotencyKey,
      idempotencyKey,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    txn.set(transactionRef, {
      transactionId: idempotencyKey,
      paymentId,
      tenantId,
      ownerId,
      propertyId,
      amount,
      currency,
      gateway: 'razorpay',
      status: 'initiated',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  const { keyId, keySecret } = getRazorpayConfig();
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError('failed-precondition', 'Razorpay keys not configured');
  }

  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const receipt = paymentId;
  const orderRes = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: amountInPaise,
      currency,
      receipt,
      notes: {
        paymentId,
        tenantId,
        propertyId,
        ownerId,
      },
    }),
  });

  if (!orderRes.ok) {
    const text = await orderRes.text();
    throw new functions.https.HttpsError('internal', `Razorpay order failed: ${text}`);
  }

  const order = await orderRes.json();
  await paymentRef.set({
    razorpayOrderId: order.id,
    razorpayKeyId: keyId,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    paymentId,
    gateway: 'razorpay',
    amountInPaise: order.amount,
    currency: order.currency,
    idempotencyKey,
    orderId: order.id,
    keyId,
  };
});

exports.verifyOwnerRazorpayPayment = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  await assertOwnerAccessOrThrow(ownerId);

  const paymentId = String(data?.paymentId || '').trim();
  const payload = data?.payload || {};
  const razorpayOrderId = String(payload.orderId || '').trim();
  const razorpayPaymentId = String(payload.paymentId || '').trim();
  const razorpaySignature = String(payload.signature || '').trim();

  if (!paymentId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'paymentId and Razorpay payload (orderId, paymentId, signature) are required',
    );
  }

  const paymentRef = db.collection('payments').doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Payment not found');
  }

  const payment = paymentSnap.data() || {};
  if (String(payment.ownerId || '') !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Payment does not belong to owner');
  }

  if (String(payment.status || '').toLowerCase() === 'paid') {
    return { ok: true, status: 'already_verified' };
  }

  if (String(payment.razorpayOrderId || '') !== razorpayOrderId) {
    throw new functions.https.HttpsError('failed-precondition', 'Order mismatch for payment');
  }

  const { keyId, keySecret } = getRazorpayConfig();
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError('failed-precondition', 'Razorpay secret not configured');
  }

  const expected = crypto
    .createHmac('sha256', keySecret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest('hex');

  if (!safeEqualDigest(expected, razorpaySignature, 'hex')) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid Razorpay signature');
  }

  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const paymentFetchRes = await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(razorpayPaymentId)}`, {
    method: 'GET',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
  });

  if (!paymentFetchRes.ok) {
    const text = await paymentFetchRes.text();
    throw new functions.https.HttpsError('internal', `Razorpay payment fetch failed: ${text}`);
  }

  const remotePayment = await paymentFetchRes.json();
  const expectedAmountInPaise = Number(payment.amountInPaise || (Number(payment.amount || 0) * 100));
  const remoteAmount = Number(remotePayment.amount || 0);
  const remoteCurrency = String(remotePayment.currency || '').toUpperCase();
  const remoteOrderId = String(remotePayment.order_id || '').trim();
  const remoteStatus = String(remotePayment.status || '').trim().toLowerCase();

  if (remoteOrderId !== razorpayOrderId) {
    throw new functions.https.HttpsError('failed-precondition', 'Razorpay order validation failed');
  }
  if (remoteAmount !== expectedAmountInPaise) {
    throw new functions.https.HttpsError('failed-precondition', 'Razorpay amount validation failed');
  }
  if (remoteCurrency !== String(payment.currency || 'INR').toUpperCase()) {
    throw new functions.https.HttpsError('failed-precondition', 'Razorpay currency validation failed');
  }
  if (!['captured', 'authorized'].includes(remoteStatus)) {
    throw new functions.https.HttpsError('failed-precondition', `Razorpay payment not completed. Status: ${remoteStatus}`);
  }

  const transactionId = String(payment.transactionId || '').trim();
  const transactionRef = transactionId
    ? db.collection('transactions').doc(transactionId)
    : db.collection('transactions').doc(`rzp_${paymentId}`);

  await db.runTransaction(async (txn) => {
    const latestPayment = await txn.get(paymentRef);
    if (latestPayment.exists && String(latestPayment.get('status') || '').toLowerCase() === 'paid') {
      return;
    }

    txn.set(paymentRef, {
      status: 'paid',
      method: 'Razorpay',
      paidAmount: Number(payment.amount || 0),
      remainingAmount: 0,
      transactionId: transactionId || `rzp_${paymentId}`,
      razorpayPaymentId,
      razorpayOrderId,
      signature: razorpaySignature,
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    txn.set(transactionRef, {
      transactionId: transactionId || `rzp_${paymentId}`,
      paymentId,
      ownerId,
      tenantId: payment.tenantId || '',
      propertyId: payment.propertyId || '',
      amount: Number(payment.amount || 0),
      currency: String(payment.currency || 'INR'),
      gateway: 'razorpay',
      status: 'success',
      gatewayResponse: {
        razorpayPaymentId,
        razorpayOrderId,
        status: remoteStatus,
      },
      verificationSignature: razorpaySignature,
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return {
    ok: true,
    paymentId,
    transactionId: transactionId || `rzp_${paymentId}`,
  };
});

// ==========================================================
// OWNER SUBSCRIPTION (CASHFREE)
// ==========================================================

async function assertOwnerAccessOrThrow(ownerId) {
  const ownerUserDoc = await db.collection('users').doc(ownerId).get();
  if (!ownerUserDoc.exists) {
    // Legacy accounts might not have a synced users doc yet.
    return;
  }

  const ownerRole = String(ownerUserDoc.data()?.role || '').trim().toLowerCase();
  if (ownerRole && ownerRole !== 'owner') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only owners can perform this operation',
    );
  }
}

function toEpochMillisOrNull(value) {
  if (!value) return null;
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

exports.ensureOwnerSubscriptionProfile = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  const requestedOwnerId = String(data?.ownerId || ownerId).trim();
  if (requestedOwnerId !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid owner scope');
  }

  await assertOwnerAccessOrThrow(ownerId);

  const email = String(data?.email || '').trim();
  const ownerRef = db.collection('owners').doc(ownerId);
  const ownerDoc = await ownerRef.get();
  const current = ownerDoc.data() || {};

  const payload = {
    ownerId,
    email: email || String(current.email || ''),
    subscriptionPlan: String(current.subscriptionPlan || 'free').toLowerCase(),
    paymentStatus: String(current.paymentStatus || 'active').toLowerCase(),
    tenantLimit: Number.isFinite(current.tenantLimit) ? Number(current.tenantLimit) : 2,
    currentTenantCount: Number.isFinite(current.currentTenantCount)
      ? Number(current.currentTenantCount)
      : 0,
    updatedAt: FieldValue.serverTimestamp(),
    ...(current.subscriptionStartDate ? {} : { subscriptionStartDate: FieldValue.serverTimestamp() }),
  };

  await ownerRef.set(payload, { merge: true });
  return { ok: true };
});

exports.getOwnerSubscriptionSnapshot = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  const requestedOwnerId = String(data?.ownerId || ownerId).trim();
  if (requestedOwnerId !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid owner scope');
  }

  await assertOwnerAccessOrThrow(ownerId);

  const email = String(data?.email || '').trim();
  const ownerRef = db.collection('owners').doc(ownerId);
  const ownerDoc = await ownerRef.get();
  const current = ownerDoc.data() || {};

  if (!ownerDoc.exists) {
    await ownerRef.set({
      ownerId,
      email,
      subscriptionPlan: 'free',
      paymentStatus: 'active',
      tenantLimit: 2,
      currentTenantCount: 0,
      subscriptionStartDate: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  } else if (email && current.email !== email) {
    await ownerRef.set({ email, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  const finalDoc = await ownerRef.get();
  const finalData = finalDoc.data() || {};

  return {
    ownerId,
    email: String(finalData.email || email || ''),
    subscriptionPlan: String(finalData.subscriptionPlan || 'free').toLowerCase(),
    paymentStatus: String(finalData.paymentStatus || 'active').toLowerCase(),
    tenantLimit: Number.isFinite(finalData.tenantLimit) ? Number(finalData.tenantLimit) : 2,
    currentTenantCount: Number.isFinite(finalData.currentTenantCount)
      ? Number(finalData.currentTenantCount)
      : 0,
    subscriptionStartDate: toEpochMillisOrNull(finalData.subscriptionStartDate),
    subscriptionExpiry: toEpochMillisOrNull(finalData.subscriptionExpiry),
    cashfreeOrderId: finalData.cashfreeOrderId || null,
    cashfreeSubscriptionId: finalData.cashfreeSubscriptionId || null,
  };
});

exports.activateOwnerFreeSubscription = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  const requestedOwnerId = String(data?.ownerId || ownerId).trim();
  if (requestedOwnerId !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid owner scope');
  }

  await assertOwnerAccessOrThrow(ownerId);

  await db.collection('owners').doc(ownerId).set({
    ownerId,
    subscriptionPlan: 'free',
    paymentStatus: 'active',
    tenantLimit: 2,
    subscriptionExpiry: null,
    subscriptionStartDate: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true, subscriptionPlan: 'free', tenantLimit: 2, paymentStatus: 'active' };
});

exports.createOwnerSubscriptionPaymentIntent = functions.https.onCall(async (data, context) => {
  // Production-grade Cashfree payment intent creation
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  await assertOwnerAccessOrThrow(ownerId);

  const planCode = String(data?.planCode || '').trim().toLowerCase();
  
  // Plan configurations with Cashfree amounts in paise (amount * 100)
  const plans = {
    basic: { 
      amountInPaise: 9900,  // ₹99
      tenantLimit: 10,
      displayName: 'Basic Plan'
    },
    pro: { 
      amountInPaise: 49900,  // ₹499
      tenantLimit: 50,
      displayName: 'Pro Plan'
    },
  };

  const plan = plans[planCode];
  if (!plan) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Only paid plans (basic/pro) can create subscription payment intents',
    );
  }

  const { appId, secretKey, isSandbox } = getCashfreeConfig();
  if (!appId || !secretKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Cashfree not configured. Set cashfree.app_id and cashfree.secret_key in Firebase config.',
    );
  }

  try {
    const currency = 'INR';
    const paymentId = `sub_${ownerId}_${Date.now()}`;
    const cashfreeOrderId = `order_${paymentId}`;
    const cashfreeBaseUrl = isSandbox
      ? 'https://test.cashfree.com'
      : 'https://api.cashfree.com';

    // Create Cashfree payment session token
    const tokenResponse = await fetch(`${cashfreeBaseUrl}/api/v2/cftoken/order`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': appId,
        'x-client-secret': secretKey,
      },
      body: JSON.stringify({
        orderId: cashfreeOrderId,
        orderAmount: (plan.amountInPaise / 100).toFixed(2),
        orderCurrency: currency,
      }),
    });

    if (!tokenResponse.ok) {
      const errText = await tokenResponse.text();
      functions.logger.error('Cashfree token creation failed', { 
        status: tokenResponse.status, 
        error: errText 
      });
      throw new functions.https.HttpsError(
        'internal',
        `Cashfree token creation failed: ${errText}`,
      );
    }

    const tokenData = await tokenResponse.json();
    if (tokenData.status !== 'OK') {
      throw new functions.https.HttpsError(
        'internal',
        `Cashfree error: ${tokenData.message || 'Unknown error'}`,
      );
    }

    const paymentSessionId = tokenData.cftoken;

    // Store payment intent in Firestore for tracking
    await db.collection('subscriptionPayments').doc(paymentId).set({
      paymentId,
      ownerId,
      planCode,
      tenantLimit: plan.tenantLimit,
      amountInPaise: plan.amountInPaise,
      currency,
      gateway: 'cashfree',
      status: 'pending',
      cashfreeOrderId,
      cashfreePaymentSessionId: paymentSessionId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 15 * 60 * 1000)), // 15 min expiry
    });

    functions.logger.info('Payment intent created', { 
      paymentId, 
      ownerId, 
      planCode 
    });

    return {
      paymentId,
      orderId: cashfreeOrderId,
      paymentSessionId,
      keyId: appId,
      amountInPaise: plan.amountInPaise,
      currency,
      planCode,
      tenantLimit: plan.tenantLimit,
    };
  } catch (error) {
    functions.logger.error('Payment intent creation error', { 
      error: error.message,
      ownerId,
      planCode
    });
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

exports.verifyOwnerSubscriptionPayment = functions.https.onCall(async (data, context) => {
  // Production-grade Cashfree payment verification
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  await assertOwnerAccessOrThrow(ownerId);

  const paymentId = String(data?.paymentId || '').trim();
  if (!paymentId) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentId is required');
  }

  try {
    const paymentRef = db.collection('subscriptionPayments').doc(paymentId);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Subscription payment not found');
    }

    const paymentData = paymentDoc.data();
    if (paymentData.ownerId !== ownerId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Payment does not belong to current owner',
      );
    }

    // Check if payment already processed
    if (paymentData.status === 'verified' || paymentData.status === 'paid') {
      functions.logger.info('Payment already verified', { paymentId, ownerId });
      return { ok: true, status: 'already_verified' };
    }

    const cashfreeOrderId = paymentData.cashfreeOrderId;
    if (!cashfreeOrderId) {
      throw new functions.https.HttpsError('failed-precondition', 'Cashfree order ID not found');
    }

    const { appId, secretKey, isSandbox } = getCashfreeConfig();
    if (!appId || !secretKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Cashfree not configured');
    }

    const cashfreeBaseUrl = isSandbox
      ? 'https://test.cashfree.com'
      : 'https://api.cashfree.com';

    // Fetch order status from Cashfree
    const orderRes = await fetch(
      `${cashfreeBaseUrl}/api/v2/orders/${cashfreeOrderId}`,
      {
        method: 'GET',
        headers: {
          'x-client-id': appId,
          'x-client-secret': secretKey,
        },
      }
    );

    if (!orderRes.ok) {
      const errText = await orderRes.text();
      functions.logger.error('Cashfree order fetch failed', { 
        status: orderRes.status, 
        error: errText 
      });
      throw new functions.https.HttpsError(
        'internal',
        `Cashfree order fetch failed: ${errText}`,
      );
    }

    const orderData = await orderRes.json();
    if (orderData.orderStatus !== 'PAID') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Payment not completed. Status: ${orderData.orderStatus}`,
      );
    }

    // Payment verified! Update Firestore with subscription
    const planCode = String(paymentData.planCode || 'free');
    const tenantLimit = Number(paymentData.tenantLimit || 2);
    const now = new Date();
    const expiryDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 days
    const cfTransactionId = orderData.referenceId?.toString() || cashfreeOrderId;

    // Use transaction to ensure consistency
    await db.runTransaction(async (txn) => {
      // Update payment record
      txn.set(
        paymentRef,
        {
          status: 'paid',
          transactionId: cfTransactionId,
          paidAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Update owner subscription
      txn.set(
        db.collection('owners').doc(ownerId),
        {
          ownerId,
          subscriptionPlan: planCode,
          tenantLimit,
          paymentStatus: 'active',
          subscriptionStartDate: FieldValue.serverTimestamp(),
          subscriptionExpiry: Timestamp.fromDate(expiryDate),
          cashfreeOrderId,
          cashfreeSubscriptionId: cfTransactionId,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    functions.logger.info('Payment verified and subscription activated', { 
      paymentId, 
      ownerId, 
      planCode,
      transactionId: cfTransactionId
    });

    return {
      ok: true,
      status: 'active',
      subscriptionPlan: planCode,
      tenantLimit,
      paymentId,
    };
  } catch (error) {
    functions.logger.error('Payment verification error', { 
      error: error.message,
      paymentId,
      ownerId
    });
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message);
  }
});

function trustStatusLabel(score) {
  const clamped = Math.max(0, Math.min(100, Number(score) || 0));
  if (clamped >= 80) return 'Highly Trusted';
  if (clamped >= 60) return 'Reliable';
  if (clamped >= 40) return 'Average Risk';
  if (clamped >= 20) return 'High Risk';
  return 'Very Risky Tenant';
}

exports.lookupTenantTrustScore = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  await assertOwnerAccessOrThrow(ownerId);

  const rawPhone = String(data?.phoneNumber || '').trim();
  const digits = rawPhone.replace(/\D/g, '');
  let localPhone = '';
  if (digits.length === 10 && /^[6-9]/.test(digits)) {
    localPhone = digits;
  } else if (digits.length === 12 && digits.startsWith('91') && /^[6-9]/.test(digits.slice(2))) {
    localPhone = digits.slice(2);
  }

  if (!localPhone) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number format');
  }

  const dayKey = new Date().toISOString().slice(0, 10);
  const quotaRef = db.collection('ownerTrustScoreLookupQuota').doc(`${ownerId}_${dayKey}`);
  const eventRef = db.collection('ownerTrustScoreLookupEvents').doc();

  await db.runTransaction(async (txn) => {
    const quotaDoc = await txn.get(quotaRef);
    const currentCount = quotaDoc.exists ? Number(quotaDoc.data()?.count || 0) : 0;
    if (currentCount >= 30) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Daily lookup limit reached (30/day).',
      );
    }

    txn.set(quotaRef, {
      ownerId,
      dayKey,
      count: currentCount + 1,
      updatedAt: FieldValue.serverTimestamp(),
      ...(quotaDoc.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
    }, { merge: true });
  });

  const normalized91 = `91${localPhone}`;

  const snapshots = [];
  snapshots.push(await db.collection('tenants').where('phoneNumber', '==', localPhone).limit(5).get());
  if (snapshots[snapshots.length - 1].empty) {
    snapshots.push(await db.collection('tenants').where('phoneNumber', '==', normalized91).limit(5).get());
  }
  if (snapshots[snapshots.length - 1].empty) {
    snapshots.push(await db.collection('tenants').where('phone', '==', localPhone).limit(5).get());
  }
  if (snapshots[snapshots.length - 1].empty) {
    snapshots.push(await db.collection('tenants').where('phone', '==', normalized91).limit(5).get());
  }

  const docsById = new Map();
  snapshots.forEach((snap) => {
    snap.docs.forEach((doc) => {
      docsById.set(doc.id, doc);
    });
  });

  const matches = Array.from(docsById.values());
  matches.sort((a, b) => {
    const as = Number(a.data()?.trustScore ?? -1);
    const bs = Number(b.data()?.trustScore ?? -1);
    return bs - as;
  });

  const best = matches[0] || null;
  let response;

  if (!best) {
    response = {
      found: false,
      displayScore: 'Unknown',
      trustScore: null,
      statusLabel: 'Unknown',
      tenantName: 'Tenant',
      multipleMatches: false,
      matchCount: 0,
      message: 'No tenant record found for this phone number.',
    };
  } else {
    const bestData = best.data() || {};
    const trustScore = bestData.trustScore;
    const hasScore = Number.isFinite(Number(trustScore));
    const score = hasScore ? Math.max(0, Math.min(100, Number(trustScore))) : null;
    const tenantName = String(bestData.fullName || bestData.name || 'Tenant');

    response = {
      found: true,
      displayScore: hasScore ? String(score) : 'N/A',
      trustScore: hasScore ? score : null,
      statusLabel: hasScore ? trustStatusLabel(score) : 'Unknown',
      tenantName,
      multipleMatches: matches.length > 1,
      matchCount: matches.length,
      message: hasScore ? 'Trust score fetched successfully.' : 'Trust score unavailable.',
    };
  }

  await eventRef.set({
    ownerId,
    dayKey,
    phoneLast4: localPhone.slice(-4),
    found: response.found,
    hasScore: response.trustScore != null,
    matchCount: response.matchCount,
    createdAt: FieldValue.serverTimestamp(),
  });

  return response;
});

// ==========================================================
// RAZORPAY INTEGRATION
// ==========================================================

exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);
  await assertTenantAccessOrThrow(context.auth.uid);

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

  const paymentRef = db.collection('payments').doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Payment not found');
  }

  const payment = paymentSnap.data() || {};
  const callerUid = context.auth.uid;
  const ownsPayment = payment.tenantId === callerUid || payment.ownerId === callerUid;
  if (!ownsPayment) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Payment does not belong to current user',
    );
  }

  const expectedAmount = Number(payment.totalAmount || payment.amount || 0);
  if (!Number.isFinite(expectedAmount) || expectedAmount <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Payment amount is invalid on server',
    );
  }

  if (amount !== expectedAmount * 100) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Amount mismatch with server payment record',
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

  await paymentRef.set(
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
    assertCallableAuth(context);
    await assertTenantAccessOrThrow(context.auth.uid);

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

    if (!safeEqualDigest(expected, razorpaySignature, 'hex')) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Invalid Razorpay signature',
      );
    }

    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentSnap = await paymentRef.get();
    if (!paymentSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment not found');
    }

    const payment = paymentSnap.data() || {};
    const callerUid = context.auth.uid;
    const ownsPayment = payment.tenantId === callerUid || payment.ownerId === callerUid;
    if (!ownsPayment) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Payment does not belong to current user',
      );
    }

    const storedOrderId = String(payment.razorpayOrderId || '').trim();
    if (!storedOrderId || storedOrderId !== razorpayOrderId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Order id does not match server payment record',
      );
    }

    await paymentRef.set(
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
  assertCallableAuth(context);

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
  assertCallableAuth(context);

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
    setCorsHeaders(req, res);
    res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Firebase-AppCheck');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  setCorsHeaders(req, res);
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    await verifyHttpAppCheckOrThrow(req);

    const authHeader = req.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      await recordSecuritySignal({
        type: 'unauthorized_http_access',
        channel: 'tenant_image_signature',
        ip: requestIpFromHeaders(req),
        reason: 'missing_bearer',
        statusCode: 401,
      });
      res.status(401).json({ error: 'Missing Authorization bearer token' });
      return;
    }

    const idToken = authHeader.replace('Bearer ', '').trim();
    if (!idToken) {
      await recordSecuritySignal({
        type: 'unauthorized_http_access',
        channel: 'tenant_image_signature',
        ip: requestIpFromHeaders(req),
        reason: 'empty_bearer',
        statusCode: 401,
      });
      res.status(401).json({ error: 'Invalid bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    await assertTenantAccessOrThrow(uid);

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
    await recordSecuritySignal({
      type: 'unauthorized_http_access',
      channel: 'tenant_image_signature',
      ip: requestIpFromHeaders(req),
      reason: String(error?.message || 'unknown_error'),
      statusCode: 401,
    });
    functions.logger.error('Failed to create Cloudinary upload signature', { error: String(error) });
    res.status(401).json({ error: 'Unauthorized' });
  }
});

exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const { webhookSecret } = getRazorpayConfig();
  if (!webhookSecret) {
    res.status(500).send('Webhook secret not configured');
    return;
  }

  const signature = req.get('X-Razorpay-Signature');
  if (!signature || !verifyWebhookSignature(req.rawBody, signature, webhookSecret)) {
    await recordSecuritySignal({
      type: 'invalid_webhook_signature',
      channel: 'razorpay',
      ip: requestIpFromHeaders(req),
      reason: 'invalid_or_missing_signature',
      statusCode: 401,
    });
    res.status(401).send('Invalid signature');
    return;
  }

  const rawBody = req.rawBody?.toString('utf8') || JSON.stringify(req.body || {});
  const eventIdHeader = String(req.get('X-Razorpay-Event-Id') || '').trim();
  const replayKey = eventIdHeader || `${signature}:${rawBody}`;
  const isFresh = await recordWebhookDelivery({
    provider: 'razorpay',
    uniqueKey: replayKey,
    rawBody,
  });
  if (!isFresh) {
    res.json({ received: true, duplicate: true });
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

// ==========================================================
// CASHFREE WEBHOOK
// ==========================================================

exports.cashfreeWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const { webhookSecret } = getCashfreeConfig();
  if (!webhookSecret) {
    res.status(500).send('Cashfree webhook secret not configured');
    return;
  }

  const signature = req.get('x-webhook-signature');
  const timestamp = req.get('x-webhook-timestamp');
  if (!signature || !timestamp) {
    await recordSecuritySignal({
      type: 'invalid_webhook_signature',
      channel: 'cashfree',
      ip: requestIpFromHeaders(req),
      reason: 'missing_signature_headers',
      statusCode: 401,
    });
    res.status(401).send('Missing signature headers');
    return;
  }

  const timestampMs = Number(timestamp) * 1000;
  if (!Number.isFinite(timestampMs)) {
    await recordSecuritySignal({
      type: 'invalid_webhook_signature',
      channel: 'cashfree',
      ip: requestIpFromHeaders(req),
      reason: 'invalid_signature_timestamp',
      statusCode: 401,
    });
    res.status(401).send('Invalid signature timestamp');
    return;
  }

  const maxAgeMs = 5 * 60 * 1000;
  if (Math.abs(Date.now() - timestampMs) > maxAgeMs) {
    await recordSecuritySignal({
      type: 'invalid_webhook_signature',
      channel: 'cashfree',
      ip: requestIpFromHeaders(req),
      reason: 'expired_signature_timestamp',
      statusCode: 401,
    });
    res.status(401).send('Expired webhook signature timestamp');
    return;
  }

  // Cashfree HMAC-SHA256: base64(HMAC(timestamp + rawBody, secret))
  const rawBody = req.rawBody?.toString('utf8') || JSON.stringify(req.body);
  const expectedSig = crypto
    .createHmac('sha256', webhookSecret)
    .update(timestamp + rawBody)
    .digest('base64');

  if (!safeEqualDigest(expectedSig, signature, 'base64')) {
    await recordSecuritySignal({
      type: 'invalid_webhook_signature',
      channel: 'cashfree',
      ip: requestIpFromHeaders(req),
      reason: 'invalid_signature',
      statusCode: 401,
    });
    res.status(401).send('Invalid signature');
    return;
  }

  const eventIdHeader = String(req.get('x-webhook-id') || '').trim();
  const replayKey = eventIdHeader || `${timestamp}:${signature}:${rawBody}`;
  const isFresh = await recordWebhookDelivery({
    provider: 'cashfree',
    uniqueKey: replayKey,
    rawBody,
  });
  if (!isFresh) {
    res.json({ received: true, duplicate: true });
    return;
  }

  const event = req.body?.type;
  const data = req.body?.data || {};

  if (event === 'PAYMENT_SUCCESS_WEBHOOK') {
    const order = data?.order || {};
    const payment = data?.payment || {};
    const cashfreeOrderId = order.order_id;
    const cfTransactionId = payment.cf_payment_id?.toString() || cashfreeOrderId;

    if (cashfreeOrderId) {
      const snap = await db
        .collection('payments')
        .where('cashfreeOrderId', '==', cashfreeOrderId)
        .limit(1)
        .get();

      if (!snap.empty) {
        const paymentId = snap.docs[0].id;
        const now = FieldValue.serverTimestamp();
        await db.collection('payments').doc(paymentId).set(
          {
            status: 'paid',
            method: 'online',
            transactionId: cfTransactionId,
            cashfreeOrderId,
            paidAt: now,
            updatedAt: now,
          },
          { merge: true },
        );
      }
    }
  } else if (event === 'PAYMENT_FAILED_WEBHOOK') {
    const order = data?.order || {};
    const payment = data?.payment || {};
    const cashfreeOrderId = order.order_id;
    const failureMsg = payment.payment_message || 'Payment failed';

    if (cashfreeOrderId) {
      const snap = await db
        .collection('payments')
        .where('cashfreeOrderId', '==', cashfreeOrderId)
        .limit(1)
        .get();

      if (!snap.empty) {
        const paymentId = snap.docs[0].id;
        await db
          .collection('messages')
          .doc(`${paymentId}_cfailed`)
          .set({
            type: 'reminder',
            title: 'Payment failed',
            body: `Cashfree payment failed (${failureMsg}).`,
            severity: 'warn',
            paymentId,
            createdAt: FieldValue.serverTimestamp(),
            read: false,
          });
      }
    }
  }

  res.json({ received: true });
});
