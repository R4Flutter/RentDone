// @ts-nocheck
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

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

// function assertEmailVerifiedOrThrow(context) {
//   if (!context?.auth?.token?.email_verified) {
//     throw new functions.https.HttpsError(
//       'failed-precondition',
//       'email-not-verified',
//     );
//   }
// }

async function getGlobalAppConfig() {
  const defaults = {
    paymentsEnabled: true,
    manualPaymentsEnabled: true,
    razorpayEnabled: true,
    maintenanceMode: false,
  };

  try {
    const snap = await db.collection('appConfig').doc('global').get();
    if (!snap.exists) return defaults;
    const data = snap.data() || {};
    return {
      paymentsEnabled: data.paymentsEnabled !== false,
      manualPaymentsEnabled: data.manualPaymentsEnabled !== false,
      razorpayEnabled: data.razorpayEnabled !== false,
      maintenanceMode: data.maintenanceMode === true,
    };
  } catch (_) {
    return defaults;
  }
}

async function assertPaymentsEnabledOrThrow({ gateway, manual = false }) {
  const config = await getGlobalAppConfig();

  if (config.maintenanceMode) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'maintenance-mode',
    );
  }

  if (!config.paymentsEnabled) {
    throw new functions.https.HttpsError(
      'unavailable',
      'payments-disabled',
    );
  }

  if (manual && !config.manualPaymentsEnabled) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'manual-payments-disabled',
    );
  }

  if (String(gateway || '').toLowerCase() === 'razorpay' && !config.razorpayEnabled) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'razorpay-disabled',
    );
  }

  return config;
}

async function assertAdminAccessOrThrow(uid) {
  if (!uid) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required',
    );
  }

  try {
    const userRecord = await admin.auth().getUser(uid);
    if (userRecord?.customClaims?.admin === true) {
      return;
    }
  } catch (_) {
    // Fall back to Firestore lookup if auth lookup fails.
  }

  const adminDoc = await db.collection('admins').doc(uid).get();
  if (adminDoc.exists && adminDoc.get('active') !== false) {
    return;
  }

  const userDoc = await db.collection('users').doc(uid).get();
  if (userDoc.exists) {
    const role = String(userDoc.data()?.role || '').trim().toLowerCase();
    if (role === 'admin') {
      return;
    }
  }

  throw new functions.https.HttpsError(
    'permission-denied',
    'Admin access required',
  );
}

async function logAdminAudit({
  action,
  adminId,
  targetId = null,
  oldValue = null,
  newValue = null,
  reason = null,
  meta = null,
}) {
  await db.collection('admin_audit_logs').add({
    action: String(action || 'unknown').trim(),
    adminId: String(adminId || '').trim(),
    targetId: targetId ? String(targetId) : null,
    oldValue: oldValue ?? null,
    newValue: newValue ?? null,
    reason: reason ? String(reason) : null,
    meta: meta ?? null,
    timestamp: FieldValue.serverTimestamp(),
  });
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

const PAYMENT_RATE_LIMIT = 5;
const PAYMENT_RATE_WINDOW_SECONDS = 60;

async function rateLimitOrThrow({
  uid,
  action,
  limit = PAYMENT_RATE_LIMIT,
  windowSeconds = PAYMENT_RATE_WINDOW_SECONDS,
  meta = {},
}) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const bucket = minuteBucketKey();
  const safeAction = String(action || 'unknown').trim().toLowerCase();
  const docId = `${safeAction}_${uid}_${bucket}`;
  const ref = db.collection('_rateLimits').doc(docId);

  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists ? Number(snap.data()?.count || 0) : 0;
      if (current >= limit) {
        throw new functions.https.HttpsError('resource-exhausted', 'rate-limited');
      }

      const expiresAt = Timestamp.fromDate(new Date(Date.now() + (24 * 60 * 60 * 1000)));
      tx.set(ref, {
        action: safeAction,
        uid,
        bucket,
        count: current + 1,
        windowSeconds,
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt,
        ...(snap.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      }, { merge: true });
    });
  } catch (error) {
    if (error instanceof functions.https.HttpsError && error.code === 'resource-exhausted') {
      await recordSecuritySignal({
        type: 'rate_limit',
        channel: safeAction,
        uid,
        reason: 'rate-limited',
        statusCode: 429,
        meta,
      });
    }
    throw error;
  }
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
  const normalizedMode = String(cfg.mode || process.env.RAZORPAY_MODE || 'test')
    .trim()
    .toLowerCase();
  const mode = normalizedMode === 'live' ? 'live' : 'test';

  const configuredGenericKeyId = String(
    cfg.key_id || process.env.RAZORPAY_KEY_ID || '',
  ).trim();

  const keyId = mode === 'live'
    ? String(
        cfg.live_key_id ||
            process.env.RAZORPAY_LIVE_KEY_ID ||
            (configuredGenericKeyId.startsWith('rzp_live_')
              ? configuredGenericKeyId
              : ''),
      ).trim()
    : String(
        cfg.test_key_id ||
            process.env.RAZORPAY_TEST_KEY_ID ||
            (configuredGenericKeyId.startsWith('rzp_test_')
              ? configuredGenericKeyId
              : 'rzp_test_SWZErkO7aPAnNO'),
      ).trim();

  const keySecret = mode === 'live'
    ? String(
        cfg.live_key_secret ||
            process.env.RAZORPAY_LIVE_KEY_SECRET ||
            cfg.key_secret ||
            process.env.RAZORPAY_KEY_SECRET ||
            '',
      ).trim()
    : String(
        cfg.test_key_secret ||
            process.env.RAZORPAY_TEST_KEY_SECRET ||
            cfg.key_secret ||
            process.env.RAZORPAY_KEY_SECRET ||
            '',
      ).trim();

  const webhookSecret = mode === 'live'
    ? String(
        cfg.live_webhook_secret ||
            process.env.RAZORPAY_LIVE_WEBHOOK_SECRET ||
            cfg.webhook_secret ||
            process.env.RAZORPAY_WEBHOOK_SECRET ||
            '',
      ).trim()
    : String(
        cfg.test_webhook_secret ||
            process.env.RAZORPAY_TEST_WEBHOOK_SECRET ||
            cfg.webhook_secret ||
            process.env.RAZORPAY_WEBHOOK_SECRET ||
            '',
      ).trim();

  const keyPrefixMismatch =
    (mode === 'test' && keyId.startsWith('rzp_live_')) ||
    (mode === 'live' && keyId.startsWith('rzp_test_'));

  return {
    mode,
    keyId,
    keySecret,
    webhookSecret,
    keyPrefixMismatch,
  };
}



async function createRazorpayOrderForPayment({
  paymentRef,
  paymentId,
  amountInPaise,
  currency,
  notes = {},
}) {
  const { keyId, keySecret, mode, keyPrefixMismatch } = getRazorpayConfig();
  if (keyPrefixMismatch) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay mode-key mismatch: mode=${mode}`,
    );
  }
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay keys not configured for mode=${mode}`,
    );
  }

  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const receipt = String(paymentId || '').trim();
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
      notes,
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
  await paymentRef.set({
    razorpayOrderId: order.id,
    razorpayKeyId: keyId,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    orderId: order.id,
    keyId,
    amount: Number(order.amount || amountInPaise),
    currency: String(order.currency || currency || 'INR'),
  };
}

function getStripeConfig() {
  const cfg = functions.config().stripe || {};
  return {
    secretKey: cfg.secret_key,
    webhookSecret: cfg.webhook_secret,
  };
}

function parsePercent(value, fallback) {
  const num = Number(value);
  if (!Number.isFinite(num) || num < 0) {
    return fallback;
  }
  return num;
}

function ceilDivide(numerator, denominator) {
  return Math.floor((numerator + denominator - 1) / denominator);
}

function percentToBps(value) {
  return Math.round(parsePercent(value, 0) * 100);
}

function defaultPaymentFeeConfig() {
  const cfg = functions.config().payment_fee || {};
  const gstPercent = parsePercent(cfg.gst_percent, 18);
  const defaultGatewayPercent = parsePercent(cfg.default_gateway_percent, 2);
  const defaultGatewayCostPercent = parsePercent(
    cfg.default_gateway_cost_percent,
    defaultGatewayPercent,
  );

  return {
    gstPercent,
    defaultGatewayPercent,
    defaultGatewayCostPercent,
    gatewayPercents: {
      razorpay: parsePercent(cfg.razorpay_percent, defaultGatewayPercent),
    },
    gatewayCostPercents: {
      razorpay: parsePercent(cfg.razorpay_cost_percent, defaultGatewayCostPercent),
    },
  };
}

async function loadPaymentFeeConfig(gateway) {
  const safeGateway = String(gateway || 'razorpay').trim().toLowerCase();

  // Production policy lock: Razorpay convenience fee is fixed at 2%
  // with 18% GST on gateway fee (effective 2.36% on base rent).
  if (safeGateway === 'razorpay') {
    return {
      gateway: safeGateway,
      gatewayPercent: 2,
      gatewayCostPercent: 2,
      gstPercent: 18,
    };
  }

  const defaults = defaultPaymentFeeConfig();

  let firestoreConfig = {};
  try {
    const cfgDoc = await db.collection('system_config').doc('payment_fee').get();
    if (cfgDoc.exists) {
      firestoreConfig = cfgDoc.data() || {};
    }
  } catch (error) {
    functions.logger.warn('Using default payment fee config. Firestore config read failed.', {
      gateway: safeGateway,
      message: error?.message || 'unknown',
    });
  }

  const gatewayPercent = parsePercent(
    firestoreConfig?.gatewayPercents?.[safeGateway]
      || firestoreConfig?.[`${safeGateway}Percent`]
      || defaults.gatewayPercents[safeGateway]
      || defaults.defaultGatewayPercent,
    defaults.defaultGatewayPercent,
  );

  const gatewayCostPercent = parsePercent(
    firestoreConfig?.gatewayCostPercents?.[safeGateway]
      || firestoreConfig?.[`${safeGateway}CostPercent`]
      || defaults.gatewayCostPercents[safeGateway]
      || defaults.defaultGatewayCostPercent,
    defaults.defaultGatewayCostPercent,
  );

  const gstPercent = parsePercent(
    firestoreConfig?.gstPercent,
    defaults.gstPercent,
  );

  return {
    gateway: safeGateway,
    gatewayPercent,
    gatewayCostPercent,
    gstPercent,
  };
}

function calculateFeeBreakdownInPaise({
  rentAmountInRupees,
  gatewayPercent,
  gstPercent,
  gatewayCostPercent,
}) {
  const rentAmount = Math.trunc(Number(rentAmountInRupees || 0));
  if (!Number.isFinite(rentAmount) || rentAmount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Rent amount must be a positive integer in rupees',
    );
  }

  const rentAmountInPaise = rentAmount * 100;
  const gstBps = percentToBps(gstPercent);
  const gatewayBps = percentToBps(gatewayPercent);
  const gatewayCostBps = percentToBps(gatewayCostPercent);

  // Round upward at every fee stage to ensure the platform never under-collects.
  const feeNumerator = rentAmountInPaise * gatewayBps * (10000 + gstBps);
  const convenienceFeeInPaise = Math.max(1, ceilDivide(feeNumerator, 10000 * 10000));

  const costNumerator = rentAmountInPaise * gatewayCostBps * (10000 + gstBps);
  const estimatedGatewayCostInPaise = Math.max(0, ceilDivide(costNumerator, 10000 * 10000));

  const totalPayableInPaise = rentAmountInPaise + convenienceFeeInPaise;
  const netProfitInPaise = convenienceFeeInPaise - estimatedGatewayCostInPaise;

  return {
    rentAmountInPaise,
    convenienceFeeInPaise,
    totalPayableInPaise,
    estimatedGatewayCostInPaise,
    netProfitInPaise,
    gatewayPercent,
    gatewayCostPercent,
    gstPercent,
  };
}

async function incrementFeeAnalytics({
  gateway,
  rentAmountInPaise,
  convenienceFeeInPaise,
  totalPayableInPaise,
  estimatedGatewayCostInPaise,
}) {
  const now = new Date();
  const period = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
  const analyticsRef = db.collection('payment_fee_analytics').doc(period);

  await analyticsRef.set({
    period,
    updatedAt: FieldValue.serverTimestamp(),
    totalTransactions: FieldValue.increment(1),
    totalRentAmountInPaise: FieldValue.increment(Math.trunc(rentAmountInPaise || 0)),
    totalFeeCollectedInPaise: FieldValue.increment(Math.trunc(convenienceFeeInPaise || 0)),
    totalGatewayCostInPaise: FieldValue.increment(Math.trunc(estimatedGatewayCostInPaise || 0)),
    totalNetProfitInPaise: FieldValue.increment(
      Math.trunc((convenienceFeeInPaise || 0) - (estimatedGatewayCostInPaise || 0)),
    ),
    totalPayableCollectedInPaise: FieldValue.increment(Math.trunc(totalPayableInPaise || 0)),
    byGateway: {
      [String(gateway || 'unknown').toLowerCase()]: {
        transactions: FieldValue.increment(1),
        feeCollectedInPaise: FieldValue.increment(Math.trunc(convenienceFeeInPaise || 0)),
        gatewayCostInPaise: FieldValue.increment(Math.trunc(estimatedGatewayCostInPaise || 0)),
      },
    },
  }, { merge: true });
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

function monthKey(date) {
  const m = String(date.getMonth() + 1).padStart(2, '0');
  return `${date.getFullYear()}-${m}`;
}

function normalizePaymentStatus(value) {
  return String(value || '').trim().toLowerCase();
}

function stableStringify(value) {
  if (value === undefined) {
    return '__undefined__';
  }
  if (value === null) {
    return 'null';
  }
  if (value instanceof admin.firestore.Timestamp) {
    return `ts:${value.toMillis()}`;
  }
  if (value instanceof Date) {
    return `dt:${value.getTime()}`;
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => stableStringify(item)).join(',')}]`;
  }
  if (typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return `{${keys.map((key) => `${key}:${stableStringify(value[key])}`).join(',')}}`;
  }
  return String(value);
}

function hasAnyFieldChanged(beforeData, afterData, fields) {
  return fields.some((field) => {
    const beforeValue = beforeData?.[field];
    const afterValue = afterData?.[field];
    return stableStringify(beforeValue) !== stableStringify(afterValue);
  });
}

function shouldRecomputeOwnerSummaryForPaymentWrite(change) {
  const beforeExists = change.before.exists;
  const afterExists = change.after.exists;
  if (beforeExists !== afterExists) {
    return true;
  }
  if (!beforeExists && !afterExists) {
    return false;
  }

  const beforeData = change.before.data() || {};
  const afterData = change.after.data() || {};
  const ownerChanged = String(beforeData.ownerId || '').trim() !== String(afterData.ownerId || '').trim();
  if (ownerChanged) {
    return true;
  }

  return hasAnyFieldChanged(beforeData, afterData, [
    'status',
    'amount',
    'baseAmount',
    'paidAmount',
    'paidAt',
    'dueDate',
    'date',
    'method',
    'paymentMethod',
    'tenantId',
  ]);
}

function shouldRecomputeOwnerSummaryForTenantWrite(change) {
  const beforeExists = change.before.exists;
  const afterExists = change.after.exists;
  if (beforeExists !== afterExists) {
    return true;
  }
  if (!beforeExists && !afterExists) {
    return false;
  }

  const beforeData = change.before.data() || {};
  const afterData = change.after.data() || {};
  return String(beforeData.ownerId || '').trim() !== String(afterData.ownerId || '').trim();
}

function shouldRecomputeOwnerSummaryForPropertyWrite(change) {
  const beforeExists = change.before.exists;
  const afterExists = change.after.exists;
  if (beforeExists !== afterExists) {
    return true;
  }
  if (!beforeExists && !afterExists) {
    return false;
  }

  const beforeData = change.before.data() || {};
  const afterData = change.after.data() || {};
  const ownerChanged = String(beforeData.ownerId || '').trim() !== String(afterData.ownerId || '').trim();
  if (ownerChanged) {
    return true;
  }

  return hasAnyFieldChanged(beforeData, afterData, ['rooms']);
}

function isUnpaidStatus(value) {
  const status = normalizePaymentStatus(value);
  return status === 'unpaid' || status === 'pending';
}

function amountInr(value) {
  const amount = Number(value || 0);
  return new Intl.NumberFormat('en-IN').format(Number.isFinite(amount) ? amount : 0);
}

function dueDateLabel(value) {
  const date = toDate(value) || new Date();
  return new Intl.DateTimeFormat('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Kolkata',
  }).format(date);
}

function todayBoundsInKolkata(date = new Date()) {
  const inKolkata = new Date(date.toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
  const start = new Date(inKolkata.getFullYear(), inKolkata.getMonth(), inKolkata.getDate());
  const end = new Date(inKolkata.getFullYear(), inKolkata.getMonth(), inKolkata.getDate() + 1);
  return { now: inKolkata, start, end };
}

async function shouldSendUserNotification({ uid, notificationKey }) {
  if (!uid || !notificationKey) {
    return { allowed: false, tokens: [] };
  }

  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    return { allowed: false, tokens: [] };
  }

  const userData = userDoc.data() || {};
  const notifications = userData.notifications || {};
  const enabled = notifications[notificationKey] !== false;
  if (!enabled) {
    return {
      allowed: false,
      tokens: [],
      userRef: userDoc.ref,
    };
  }

  const tokenSnap = await userDoc.ref.collection('deviceTokens').get();
  const tokens = [];
  const tokenRefs = new Map();
  tokenSnap.forEach((doc) => {
    const token = String(doc.data()?.token || doc.id || '').trim();
    if (!token) return;
    tokens.push(token);
    tokenRefs.set(token, doc.ref);
  });

  if (!tokens.length) {
    const legacyToken = String(userData.fcmToken || '').trim();
    if (legacyToken) {
      tokens.push(legacyToken);
    }
  }

  return {
    allowed: enabled,
    tokens,
    tokenRefs,
    userRef: userDoc.ref,
  };
}

async function reserveNotificationEvent(eventId, payload) {
  const ref = db.collection('_notificationEvents').doc(eventId);
  try {
    await ref.create({
      ...payload,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(new Date(Date.now() + (30 * 24 * 60 * 60 * 1000))),
    });
    return true;
  } catch (error) {
    if (error?.code === 6 || String(error?.message || '').toLowerCase().includes('already exists')) {
      return false;
    }
    throw error;
  }
}

async function sendDirectPush({ token, title, body, data = {} }) {
  if (!token) return { sent: false, invalidToken: false };

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });
    return { sent: true, invalidToken: false };
  } catch (error) {
    const code = String(error?.code || '');
    const invalidToken = code.includes('registration-token-not-registered')
      || code.includes('invalid-registration-token');
    functions.logger.error('FCM send failed', { code, message: error?.message });
    return { sent: false, invalidToken };
  }
}

async function sendPushMulticast({ tokens, title, body, data = {} }) {
  const uniqueTokens = Array.from(new Set((tokens || []).filter(Boolean)));
  if (!uniqueTokens.length) {
    return { sentCount: 0, invalidTokens: [] };
  }

  const invalidTokens = [];
  const retryTokens = [];
  let sentCount = 0;

  for (let i = 0; i < uniqueTokens.length; i += 500) {
    const chunk = uniqueTokens.slice(i, i + 500);
    const response = await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    });

    sentCount += response.successCount;
    response.responses.forEach((item, index) => {
      if (item.success) return;
      const code = String(item.error?.code || '');
      const invalid = code.includes('registration-token-not-registered')
        || code.includes('invalid-registration-token');
      if (invalid) {
        invalidTokens.push(chunk[index]);
        return;
      }

      const transient = code.includes('internal')
        || code.includes('unavailable')
        || code.includes('deadline-exceeded')
        || code.includes('unknown');
      if (transient) {
        retryTokens.push(chunk[index]);
      }
    });
  }

  if (retryTokens.length) {
    const uniqueRetryTokens = Array.from(new Set(retryTokens));
    for (let i = 0; i < uniqueRetryTokens.length; i += 500) {
      const chunk = uniqueRetryTokens.slice(i, i + 500);
      const retryResponse = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        data,
        android: {
          priority: 'high',
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });

      sentCount += retryResponse.successCount;
      retryResponse.responses.forEach((item, index) => {
        if (item.success) return;
        const code = String(item.error?.code || '');
        const invalid = code.includes('registration-token-not-registered')
          || code.includes('invalid-registration-token');
        if (invalid) {
          invalidTokens.push(chunk[index]);
        }
      });
    }
  }

  return {
    sentCount,
    invalidTokens,
  };
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
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
}

function normalizeIndianPhone(value) {
  if (!value) return null;
  const digits = String(value).replace(/\D/g, '');
  if (digits.length === 10) return `91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return digits;
  return null;
}


async function getLeaseOrTenantPaymentContext({ leaseId, uid }) {
  const safeLeaseId = String(leaseId || '').trim();
  const safeUid = String(uid || '').trim();

  if (safeLeaseId) {
    const leaseDoc = await db.collection('leases').doc(safeLeaseId).get();
    if (leaseDoc.exists) {
      return { leaseId: safeLeaseId, lease: leaseDoc.data() || {} };
    }
  }

  const tenantDoc = await db.collection('tenants').doc(safeUid).get();
  if (!tenantDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Tenant not found');
  }

  const tenant = tenantDoc.data() || {};
  const resolvedRentAmount = normalizeIntegerAmount(
    tenant.rentAmount || tenant.dueAmount || 0,
  );

  if (!Number.isInteger(resolvedRentAmount) || resolvedRentAmount <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Calculated rent amount is invalid',
    );
  }

  return {
    leaseId: safeLeaseId || safeUid,
    lease: {
      tenantId: safeUid,
      ownerId: String(tenant.ownerId || '').trim(),
      propertyId: String(tenant.propertyId || '').trim(),
      propertyName: String(tenant.propertyName || '').trim(),
      ownerName: String(tenant.ownerName || '').trim(),
      rentAmount: resolvedRentAmount,
      dueAmount: normalizeIntegerAmount(tenant.dueAmount || resolvedRentAmount),
      dueDate: tenant.dueDate || tenant.nextDueDate || null,
      rentDueDay: Number(tenant.rentDueDay || 1),
      lateFeePercentage: Number(tenant.lateFeePercentage || 0),
      currency: String(tenant.currency || 'INR').trim() || 'INR',
      status: tenant.isActive == false ? 'inactive' : 'active',
    },
  };
}
async function resolveTenantCandidateIds(uid) {
  const ids = new Set();
  ids.add(String(uid || '').trim());

  try {
    const userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      const userData = userDoc.data() || {};
      const linkedTenantId = String(userData.tenantId || '').trim();
      if (linkedTenantId) ids.add(linkedTenantId);
    }
  } catch (_) {}

  try {
    const directTenantDoc = await db.collection('tenants').doc(uid).get();
    if (directTenantDoc.exists) {
      ids.add(directTenantDoc.id);
    }
  } catch (_) {}

  try {
    const byAuthUid = await db
      .collection('tenants')
      .where('authUid', '==', uid)
      .limit(1)
      .get();

    if (!byAuthUid.empty) {
      ids.add(byAuthUid.docs[0].id);
    }
  } catch (_) {}

  return Array.from(ids);
}

async function leaseBelongsToTenant(lease, uid) {
  const leaseTenantId = String(lease.tenantId || '').trim();
  if (!leaseTenantId) return true;

  const candidateIds = await resolveTenantCandidateIds(uid);
  return candidateIds.includes(leaseTenantId);
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

async function deleteQueryInChunksCapped(query, {
  chunkSize = 400,
  maxDocs = 1200,
} = {}) {
  let deleted = 0;
  while (deleted < maxDocs) {
    const remaining = maxDocs - deleted;
    const effectiveChunk = Math.min(chunkSize, remaining);
    const snapshot = await query.limit(effectiveChunk).get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    deleted += snapshot.size;

    if (snapshot.size < effectiveChunk) {
      break;
    }
  }
  return deleted;
}

function isSameMonth(date, now = new Date()) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    return false;
  }
  return date.getFullYear() === now.getFullYear()
    && date.getMonth() === now.getMonth();
}

async function recomputeOwnerSummary(ownerId) {
  const safeOwnerId = String(ownerId || '').trim();
  if (!safeOwnerId) {
    return;
  }

  const [propertiesSnap, tenantsSnap, paymentsSnap] = await Promise.all([
    db.collection('properties').where('ownerId', '==', safeOwnerId).get(),
    db.collection('tenants').where('ownerId', '==', safeOwnerId).get(),
    db.collection('payments').where('ownerId', '==', safeOwnerId).get(),
  ]);

  const totalProperties = propertiesSnap.size;
  const totalTenants = tenantsSnap.size;

  let vacantProperties = 0;
  propertiesSnap.forEach((doc) => {
    const rooms = Array.isArray(doc.data()?.rooms) ? doc.data().rooms : [];
    const occupied = rooms.filter((room) => room?.isOccupied === true).length;
    vacantProperties += Math.max(rooms.length - occupied, 0);
  });

  const now = new Date();
  let collectedAmount = 0;
  let collectedPayments = 0;
  let pendingAmount = 0;
  let pendingPayments = 0;
  const pendingTenantIds = new Set();
  let cashAmount = 0;
  let onlineAmount = 0;
  let lastPaymentAt = null;

  paymentsSnap.forEach((doc) => {
    const payment = doc.data() || {};
    const status = normalizePaymentStatus(payment.status);
    const amount = Number(payment.amount || payment.baseAmount || 0) || 0;
    const paidAmountRaw = Number(payment.paidAmount || 0) || 0;
    const paidAmount = paidAmountRaw > 0 ? paidAmountRaw : amount;

    const paidAt = toDate(payment.paidAt)
      || toDate(payment.date)
      || toDate(payment.updatedAt)
      || toDate(payment.createdAt)
      || new Date();
    const dueDate = toDate(payment.dueDate)
      || toDate(payment.date)
      || toDate(payment.createdAt)
      || new Date();

    const collected = status === 'paid' || (status === 'partial' && paidAmount > 0);

    if (collected && isSameMonth(paidAt, now)) {
      collectedPayments += 1;
      collectedAmount += paidAmount;
      if (!lastPaymentAt || paidAt > lastPaymentAt) {
        lastPaymentAt = paidAt;
      }

      const method = String(payment.method || payment.paymentMethod || '').trim().toLowerCase();
      if (method === 'cash') {
        cashAmount += paidAmount;
      } else if (method === 'upi' || method === 'online' || method === 'razorpay') {
        onlineAmount += paidAmount;
      }
    }

    if (status !== 'paid' && isSameMonth(dueDate, now)) {
      pendingPayments += 1;
      pendingAmount += amount;
      const tenantId = String(payment.tenantId || '').trim();
      if (tenantId) {
        pendingTenantIds.add(tenantId);
      }
    }
  });

  const summaryPayload = {
    ownerId: safeOwnerId,
    totalProperties,
    vacantProperties,
    totalTenants,
    collectedAmount,
    collectedPayments,
    pendingAmount,
    pendingPayments,
    pendingTenants: pendingTenantIds.size,
    cashAmount,
    onlineAmount,
    totalRent: collectedAmount + pendingAmount,
    pendingRent: pendingAmount,
    paidRent: collectedAmount,
    tenantCount: totalTenants,
    lastPaymentDate: lastPaymentAt ? Timestamp.fromDate(lastPaymentAt) : null,
    lastUpdated: FieldValue.serverTimestamp(),
  };

  await db.collection('owners_summary').doc(safeOwnerId).set(summaryPayload, { merge: true });
}

async function deleteStoragePathIfExists(path) {
  const safePath = String(path || '').trim();
  if (!safePath) {
    return;
  }

  try {
    await admin.storage().bucket().file(safePath).delete();
  } catch (error) {
    const code = String(error?.code || '').toLowerCase();
    const message = String(error?.message || '').toLowerCase();
    const isNotFound = code === '404'
      || code === 'storage/object-not-found'
      || message.includes('no such object');
    if (!isNotFound) {
      throw error;
    }
  }
}

async function cleanupOrphanTenantDocumentFiles({
  staleHours = 48,
  maxDocs = 250,
} = {}) {
  const cutoff = Timestamp.fromDate(new Date(Date.now() - (staleHours * 60 * 60 * 1000)));

  const staleImagesSnap = await db
    .collection('user_images')
    .where('uploadedAt', '<=', cutoff)
    .limit(maxDocs)
    .get();

  let deletedCount = 0;
  for (const doc of staleImagesSnap.docs) {
    const data = doc.data() || {};
    const storagePath = String(data.storagePath || '').trim();
    const thumbnailStoragePath = String(data.thumbnailStoragePath || '').trim();

    if (!storagePath) {
      await doc.ref.delete();
      deletedCount += 1;
      continue;
    }

    const activeDocumentSnap = await db
      .collectionGroup('documents')
      .where('storagePath', '==', storagePath)
      .limit(1)
      .get();

    if (!activeDocumentSnap.empty) {
      continue;
    }

    await deleteStoragePathIfExists(storagePath);
    if (thumbnailStoragePath) {
      await deleteStoragePathIfExists(thumbnailStoragePath);
    }
    await doc.ref.delete();
    deletedCount += 1;
  }

  return deletedCount;
}

async function cleanupOldReportExports({
  olderThanDays = 14,
  maxFiles = 500,
} = {}) {
  const cutoff = new Date(Date.now() - (olderThanDays * 24 * 60 * 60 * 1000));
  const [files] = await admin.storage().bucket().getFiles({
    prefix: 'reports/',
    autoPaginate: false,
    maxResults: maxFiles,
  });

  let deletedCount = 0;
  for (const file of files) {
    const metaDate = toDate(file?.metadata?.updated)
      || toDate(file?.metadata?.timeCreated);
    if (!metaDate || metaDate > cutoff) {
      continue;
    }
    await deleteStoragePathIfExists(file.name);
    deletedCount += 1;
  }

  return deletedCount;
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

export const cleanupExpiredWebhookEvents = functions
  .runWith({ memory: '128MB', timeoutSeconds: 120 })
  .pubsub
  .schedule('every day 03:40')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const deletedWebhookEvents = await deleteQueryInChunksCapped(
      db.collection('_webhookEvents').where('expiresAt', '<=', now),
      { chunkSize: 300, maxDocs: 1200 },
    );
    const deletedSecuritySignals = await deleteQueryInChunksCapped(
      db.collection('_securitySignals').where('expiresAt', '<=', now),
      { chunkSize: 300, maxDocs: 1200 },
    );
    const deletedSecurityAlerts = await deleteQueryInChunksCapped(
      db.collection('_securityAlerts').where('expiresAt', '<=', now),
      { chunkSize: 300, maxDocs: 1200 },
    );
    const deletedNotificationEvents = await deleteQueryInChunksCapped(
      db.collection('_notificationEvents').where('expiresAt', '<=', now),
      { chunkSize: 300, maxDocs: 1200 },
    );

    const deletedTotal = deletedWebhookEvents
      + deletedSecuritySignals
      + deletedSecurityAlerts
      + deletedNotificationEvents;
    if (deletedTotal > 0) {
      functions.logger.info('cleanupExpiredWebhookEvents deleted expired docs', {
        deletedWebhookEvents,
        deletedSecuritySignals,
        deletedSecurityAlerts,
        deletedNotificationEvents,
      });
    }
    return null;
  });

export const cleanupStorageOrphansAndExports = functions
  .runWith({ memory: '256MB', timeoutSeconds: 240 })
  .pubsub
  .schedule('every day 03:10')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const deletedOrphans = await cleanupOrphanTenantDocumentFiles({
      staleHours: 48,
      maxDocs: 250,
    });
    const deletedReports = await cleanupOldReportExports({
      olderThanDays: 14,
      maxFiles: 500,
    });

    if (deletedOrphans > 0 || deletedReports > 0) {
      functions.logger.info('Storage cleanup finished', {
        deletedOrphans,
        deletedReports,
      });
    }

    return null;
  });

export const syncOwnerSummaryOnPaymentWrite = functions
  .runWith({ memory: '128MB', timeoutSeconds: 90 })
  .firestore
  .document('payments/{paymentId}')
  .onWrite(async (change) => {
    if (!shouldRecomputeOwnerSummaryForPaymentWrite(change)) {
      return null;
    }

    const beforeOwnerId = String(change.before.data()?.ownerId || '').trim();
    const afterOwnerId = String(change.after.data()?.ownerId || '').trim();
    const ownerIds = new Set([beforeOwnerId, afterOwnerId]);
    ownerIds.delete('');

    await Promise.all(Array.from(ownerIds).map((ownerId) => recomputeOwnerSummary(ownerId)));
    return null;
  });

export const syncOwnerSummaryOnTenantWrite = functions
  .runWith({ memory: '128MB', timeoutSeconds: 90 })
  .firestore
  .document('tenants/{tenantId}')
  .onWrite(async (change) => {
    if (!shouldRecomputeOwnerSummaryForTenantWrite(change)) {
      return null;
    }

    const beforeOwnerId = String(change.before.data()?.ownerId || '').trim();
    const afterOwnerId = String(change.after.data()?.ownerId || '').trim();
    const ownerIds = new Set([beforeOwnerId, afterOwnerId]);
    ownerIds.delete('');

    await Promise.all(Array.from(ownerIds).map((ownerId) => recomputeOwnerSummary(ownerId)));
    return null;
  });

export const syncOwnerSummaryOnPropertyWrite = functions
  .runWith({ memory: '128MB', timeoutSeconds: 90 })
  .firestore
  .document('properties/{propertyId}')
  .onWrite(async (change) => {
    if (!shouldRecomputeOwnerSummaryForPropertyWrite(change)) {
      return null;
    }

    const beforeOwnerId = String(change.before.data()?.ownerId || '').trim();
    const afterOwnerId = String(change.after.data()?.ownerId || '').trim();
    const ownerIds = new Set([beforeOwnerId, afterOwnerId]);
    ownerIds.delete('');

    await Promise.all(Array.from(ownerIds).map((ownerId) => recomputeOwnerSummary(ownerId)));
    return null;
  });

export const generateMonthlyPayments = functions
  .runWith({ memory: '256MB', timeoutSeconds: 540 })
  .pubsub
  .schedule('0 0 1 * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const now = new Date();
    const period = monthKey(now);
    const year = now.getFullYear();
    const month = now.getMonth() + 1;

    const tenantsSnap = await db
      .collection('tenants')
      .where('status', '==', 'active')
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
      if (!t.rentAmount || t.rentAmount <= 0) return;

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

export const sendRentDueReminders = functions
  .runWith({ memory: '256MB', timeoutSeconds: 300 })
  .pubsub
  .schedule('0 9 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const { now, start, end } = todayBoundsInKolkata();
    const dateKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    const dueSnap = await db
      .collection('tenants')
      .where('status', 'in', ['ACTIVE', 'active'])
      .where('dueDate', '>=', start)
      .where('dueDate', '<', end)
      .get();

    if (dueSnap.empty) return null;

    const userCache = new Map();
    let sentCount = 0;
    const cycleStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const cycleEnd = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    for (const tenantDoc of dueSnap.docs) {
      const tenant = tenantDoc.data() || {};
      const ownerId = String(tenant.ownerId || '').trim();
      const tenantId = String(tenantDoc.id || '').trim();
      if (!ownerId || !tenantId) {
        continue;
      }

      // Skip if already paid for the current cycle.
      const paymentSnap = await db
        .collection('payments')
        .where('tenantId', '==', tenantId)
        .where('paidDate', '>=', cycleStart)
        .where('paidDate', '<', cycleEnd)
        .limit(1)
        .get();
      if (!paymentSnap.empty) {
        continue;
      }

      let userNotification = userCache.get(ownerId);
      if (!userNotification) {
        userNotification = await shouldSendUserNotification({
          uid: ownerId,
          notificationKey: 'rent_due',
        });
        userCache.set(ownerId, userNotification);
      }

      if (!userNotification.allowed) {
        continue;
      }

      const eventId = `rent_due_${tenantId}_${dateKey}`;
      const reserved = await reserveNotificationEvent(eventId, {
        type: 'rent_due',
        ownerId,
        tenantId,
        dateKey,
      });
      if (!reserved) {
        continue;
      }

      const tenantName = String(tenant.fullName || tenant.name || 'Tenant').trim();
      const amount = amountInr(tenant.rentAmount || 0);
      const title = 'Rent Due Reminder';
      const body = `${tenantName}'s rent Rs ${amount} is due today`;

      await db.collection('messages').doc(eventId).set({
        type: 'rent_due',
        title,
        body,
        severity: 'info',
        ownerId,
        tenantId,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: false });

      const result = await sendPushMulticast({
        tokens: userNotification.tokens,
        title,
        body,
        data: {
          type: 'RENT_DUE',
          tenant_id: tenantId,
          tenantId,
        },
      });

      for (const invalidToken of result.invalidTokens) {
        const ref = userNotification.tokenRefs?.get(invalidToken);
        if (ref) {
          await ref.delete();
        }
      }

      sentCount += result.sentCount;
    }

    functions.logger.info('sendRentDueReminders completed', {
      scanned: dueSnap.size,
      sent: sentCount,
    });
    return null;
  });

function isPaidLikeStatus(value) {
  const status = normalizePaymentStatus(value);
  return status === 'paid' || status === 'success';
}

async function dispatchPaymentReceivedNotification({
  paymentId,
  payment,
  eventId,
}) {
  const ownerId = String(payment.ownerId || '').trim();
  const tenantId = String(payment.tenantId || '').trim();
  if (!ownerId || !tenantId) {
    return null;
  }

  const reserved = await reserveNotificationEvent(eventId, {
    type: 'payment_received',
    ownerId,
    tenantId,
    paymentId,
    eventId,
  });
  if (!reserved) {
    return null;
  }

  const userNotification = await shouldSendUserNotification({
    uid: ownerId,
    notificationKey: 'payment_received',
  });

  if (!userNotification.allowed) {
    return null;
  }

  let tenantName = 'Tenant';
  const tenantDoc = await db.collection('tenants').doc(tenantId).get();
  if (tenantDoc.exists) {
    const tenantData = tenantDoc.data() || {};
    tenantName = String(tenantData.fullName || tenantData.name || 'Tenant').trim();
  }

  const amount = amountInr(payment.amount || 0);
  const status = normalizePaymentStatus(payment.status);
  const isReceived = status === 'paid' || status === 'success';
  const title = isReceived ? 'Payment Received' : 'Payment Updated';
  const body = isReceived
    ? `Rs ${amount} received from ${tenantName}. Payment has been recorded successfully.`
    : `${tenantName}'s payment status was updated to ${status || 'updated'}. Amount: Rs ${amount}.`;

  await db
    .collection('messages')
    .doc(`payment_received_${paymentId}_${eventId}`)
    .set({
      type: 'payment_received',
      title,
      body,
      severity: 'info',
      ownerId,
      tenantId,
      paymentId,
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    });

  const result = await sendPushMulticast({
    tokens: userNotification.tokens,
    title,
    body,
    data: {
      type: isReceived ? 'PAYMENT_RECEIVED' : 'PAYMENT_UPDATED',
      notification_type: isReceived ? 'payment_received' : 'payment_updated',
      tenant_id: tenantId,
      tenantId,
      payment_id: paymentId,
      payment_status: status,
    },
  });

  for (const invalidToken of result.invalidTokens || []) {
    const ref = userNotification.tokenRefs?.get(invalidToken);
    if (ref) {
      await ref.delete();
    }
  }

  return null;
}

export const onPaymentPaid = functions.firestore
  .document('payments/{paymentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const previous = normalizePaymentStatus(before.status);
    const next = normalizePaymentStatus(after.status);

    if (previous === next) {
      return null;
    }

    // Notify for all status transitions, with special treatment for received payments.

    return dispatchPaymentReceivedNotification({
      paymentId: change.after.id,
      payment: after,
      eventId: context.eventId,
    });
  });

export const onPaymentCreatedPaid = functions.firestore
  .document('payments/{paymentId}')
  .onCreate(async (snapshot, context) => {
    const payment = snapshot.data() || {};
    const status = normalizePaymentStatus(payment.status);
    if (!status) {
      return null;
    }

    return dispatchPaymentReceivedNotification({
      paymentId: snapshot.id,
      payment,
      eventId: context.eventId,
    });
  });

// ==========================================================
// PAYMENT INTENT + VERIFICATION
// ==========================================================

const MAX_PAYMENT_AMOUNT_INR = 5000000;
const PAYMENT_DUPLICATE_WINDOW_MS = 120000;

function normalizePaymentMethod(value) {
  const method = String(value || '').trim().toLowerCase();
  if (method === 'manual' || method === 'razorpay') {
    return method;
  }
  return null;
}

function normalizeIntegerAmount(value) {
  const amount = Number(value || 0);
  if (!Number.isFinite(amount)) {
    return 0;
  }
  return Math.trunc(amount);
}

function normalizePropertyNameForComparison(value) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function resolveTenantOwnerLinkPolicy({
  tenantData,
  propertyData,
  propertyId,
  actorUid,
  enforceOwnerActor = false,
}) {
  const propertyOwnerId = String(propertyData?.ownerId || '').trim();
  const propertyName = String(propertyData?.name || '').trim();
  const tenantOwnerId = String(tenantData?.ownerId || '').trim();
  const tenantPropertyId = String(tenantData?.propertyId || '').trim();
  const tenantPropertyName = String(tenantData?.propertyName || '').trim();

  if (!propertyOwnerId) {
    throw new functions.https.HttpsError('failed-precondition', 'invalid-owner');
  }

  if (enforceOwnerActor && actorUid !== propertyOwnerId) {
    throw new functions.https.HttpsError('permission-denied', 'property-owner-mismatch');
  }

  const isLinkedTenantProfile = tenantOwnerId.length > 0 || tenantPropertyId.length > 0;

  if (isLinkedTenantProfile) {
    if (tenantOwnerId && tenantOwnerId !== propertyOwnerId) {
      throw new functions.https.HttpsError('failed-precondition', 'invalid-owner');
    }

    if (tenantPropertyId && tenantPropertyId !== propertyId) {
      throw new functions.https.HttpsError('failed-precondition', 'invalid-owner');
    }

    const normalizedTenantPropertyName = normalizePropertyNameForComparison(tenantPropertyName);
    const normalizedOwnerPropertyName = normalizePropertyNameForComparison(propertyName);
    if (
      normalizedTenantPropertyName &&
      normalizedOwnerPropertyName &&
      normalizedTenantPropertyName !== normalizedOwnerPropertyName
    ) {
      throw new functions.https.HttpsError('failed-precondition', 'property-name-mismatch');
    }
  }

  if (!isLinkedTenantProfile && actorUid !== propertyOwnerId) {
    throw new functions.https.HttpsError('permission-denied', 'tenant-link-required');
  }

  return {
    ownerId: propertyOwnerId,
    needsTenantBackfill: !tenantOwnerId || !tenantPropertyId,
    isLinkedTenantProfile,
  };
}

function hashTenantLinkToken(token) {
  return crypto
    .createHash('sha256')
    .update(String(token || '').trim(), 'utf8')
    .digest('hex');
}

function assertTenantBackfillProofOrThrow({ tenantData, providedToken }) {
  const token = String(providedToken || '').trim();
  const storedHash = String(
    tenantData?.ownerAssignmentTokenHash || tenantData?.tenantLinkTokenHash || '',
  ).trim().toLowerCase();
  const storedPlain = String(
    tenantData?.ownerAssignmentToken || tenantData?.tenantLinkToken || '',
  ).trim();

  const hasProvisionedProof = Boolean(storedHash || storedPlain);

  if (!token) {
    // Backward compatibility: allow backfill until token provisioning is enabled.
    if (!hasProvisionedProof) {
      return;
    }
    throw new functions.https.HttpsError('failed-precondition', 'tenant-link-proof-required');
  }

  if (storedHash) {
    const candidateHash = hashTenantLinkToken(token);
    if (candidateHash !== storedHash) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'tenant-link-proof-invalid',
      );
    }
    return;
  }

  if (storedPlain && token === storedPlain) {
    return;
  }

  // Backward compatibility: if no proof is stored on tenant yet, accept provided token.
  if (!hasProvisionedProof) {
    return;
  }

  throw new functions.https.HttpsError(
    'failed-precondition',
    'tenant-link-proof-missing-on-tenant',
  );
}

function resolvePaymentStatusFromAmounts({ paidAmount, remainingAmount }) {
  if (remainingAmount === 0) {
    return 'paid';
  }
  if (paidAmount > 0 && remainingAmount > 0) {
    return 'partial';
  }
  return 'pending';
}

async function logPaymentIntegrityEvent(eventType, payload) {
  try {
    await db.collection('_paymentEvents').add({
      eventType,
      ...payload,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.warn('Failed to log payment integrity event', {
      eventType,
      error: error?.message || String(error),
    });
  }
}

function normalizeLogString(value) {
  const trimmed = String(value || '').trim();
  return trimmed.length ? trimmed : null;
}

function normalizeLogNumber(value) {
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
}

function buildPaymentLogPayload({
  event,
  userId,
  tenantId,
  ownerId,
  paymentId,
  idempotencyKey,
  amount,
  method,
  status,
  errorCode,
  errorMessage,
  deviceInfo,
  extra = {},
}) {
  return {
    event: normalizeLogString(event) || 'UNKNOWN_EVENT',
    timestamp: new Date().toISOString(),
    userId: normalizeLogString(userId),
    tenantId: normalizeLogString(tenantId),
    ownerId: normalizeLogString(ownerId),
    paymentId: normalizeLogString(paymentId),
    idempotencyKey: normalizeLogString(idempotencyKey),
    amount: normalizeLogNumber(amount),
    method: normalizeLogString(method),
    status: normalizeLogString(status),
    errorCode: normalizeLogString(errorCode),
    errorMessage: normalizeLogString(errorMessage),
    deviceInfo: normalizeLogString(deviceInfo) || 'cloud-functions',
    ...extra,
  };
}

function logPaymentEvent(level, event, payload) {
  const data = buildPaymentLogPayload({ event, ...payload });
  if (level === 'error') {
    functions.logger.error(event, data);
    return;
  }
  if (level === 'warn') {
    functions.logger.warn(event, data);
    return;
  }
  functions.logger.info(event, data);
}

function validatePaymentDocumentIntegrity({
  payment,
  expectedTenantId,
  expectedOwnerId,
  expectedMethod,
}) {
  const baseAmount = normalizeIntegerAmount(payment?.baseAmount || payment?.amount);
  const paidAmount = normalizeIntegerAmount(payment?.paidAmount);
  const remainingAmount = normalizeIntegerAmount(payment?.remainingAmount);
  const status = String(payment?.status || '').trim().toLowerCase();
  const tenantId = String(payment?.tenantId || '').trim();
  const ownerId = String(payment?.ownerId || '').trim();
  const method = String(payment?.method || '').trim().toLowerCase();

  if (baseAmount <= 0) {
    return { ok: false, code: 'verification-failed', reason: 'invalid-base-amount' };
  }
  if (paidAmount < 0 || remainingAmount < 0) {
    return { ok: false, code: 'verification-failed', reason: 'negative-amounts' };
  }
  if (paidAmount + remainingAmount !== baseAmount) {
    return { ok: false, code: 'verification-failed', reason: 'amount-mismatch' };
  }

  const expectedStatus = resolvePaymentStatusFromAmounts({
    paidAmount,
    remainingAmount,
  });
  if (status !== expectedStatus) {
    return { ok: false, code: 'verification-failed', reason: 'status-mismatch' };
  }

  if (expectedTenantId && tenantId !== expectedTenantId) {
    return { ok: false, code: 'verification-failed', reason: 'tenant-mismatch' };
  }
  if (expectedOwnerId && ownerId !== expectedOwnerId) {
    return { ok: false, code: 'verification-failed', reason: 'owner-mismatch' };
  }
  if (expectedMethod && method !== String(expectedMethod).trim().toLowerCase()) {
    return { ok: false, code: 'verification-failed', reason: 'method-mismatch' };
  }

  return { ok: true };
}

async function verifyPaymentAfterWriteOrThrow({
  paymentRef,
  tenantId,
  ownerId,
  method,
  idempotencyKey,
  amount,
}) {
  const createdDoc = await paymentRef.get();
  const created = createdDoc.data() || null;
  if (!createdDoc.exists || !created) {
    await logPaymentIntegrityEvent('PAYMENT_VERIFICATION_FAILED', {
      paymentId: paymentRef.id,
      tenantId,
      ownerId,
      amount,
      method,
      idempotencyKey,
      reason: 'missing-document',
      timestamp: Date.now(),
    });
    throw new functions.https.HttpsError('internal', 'verification-failed');
  }

  const integrity = validatePaymentDocumentIntegrity({
    payment: created,
    expectedTenantId: tenantId,
    expectedOwnerId: ownerId,
    expectedMethod: method,
  });

  if (!integrity.ok) {
    await paymentRef.set(
      {
        status: 'failed',
        integrityError: integrity.reason,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await logPaymentIntegrityEvent('PAYMENT_VERIFICATION_FAILED', {
      paymentId: paymentRef.id,
      tenantId,
      ownerId,
      amount,
      method,
      idempotencyKey,
      reason: integrity.reason,
      timestamp: Date.now(),
    });

    throw new functions.https.HttpsError('internal', integrity.code);
  }

  await logPaymentIntegrityEvent('PAYMENT_VERIFIED', {
    paymentId: paymentRef.id,
    tenantId,
    ownerId,
    amount,
    method,
    idempotencyKey,
    timestamp: Date.now(),
  });
}

async function findPaymentByIdempotencyKey(idempotencyKey) {
  const existingByIdempotency = await db
    .collection('payments')
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();

  if (existingByIdempotency.empty) {
    return null;
  }

  return existingByIdempotency.docs[0];
}

async function blockDuplicatePaymentOrThrow({
  tenantId,
  amount,
  method,
  idempotencyKey,
}) {
  const duplicateCutoff = Timestamp.fromDate(new Date(Date.now() - PAYMENT_DUPLICATE_WINDOW_MS));
  const duplicates = await db
    .collection('payments')
    .where('tenantId', '==', tenantId)
    .where('baseAmount', '==', amount)
    .where('method', '==', method)
    .where('createdAt', '>=', duplicateCutoff)
    .limit(5)
    .get();

  const conflictingDoc = duplicates.docs.find((doc) => {
    const existingKey = String(doc.get('idempotencyKey') || '').trim();
    const conflictingDoc = duplicates.docs.find((doc) => {
  const existingKey = String(doc.get('idempotencyKey') || '').trim();
  const status = String(doc.get('status') || '').toLowerCase();

  if (!existingKey || existingKey === idempotencyKey) {
    return false;
  }

  // ✅ ONLY BLOCK IF PAYMENT IS ACTUALLY COMPLETED
  return status === 'paid' || status === 'success';
});
  });

  if (!conflictingDoc) {
    return;
  }

  logPaymentEvent('warn', 'DUPLICATE_BLOCKED', {
    tenantId,
    paymentId: conflictingDoc.id,
    amount,
    method,
    idempotencyKey,
    status: 'blocked',
  });

  await logPaymentIntegrityEvent('DUPLICATE_BLOCKED', {
    paymentId: conflictingDoc.id,
    tenantId,
    amount,
    method,
    idempotencyKey,
    timestamp: Date.now(),
  });

  throw new functions.https.HttpsError('already-exists', 'duplicate-payment');
}

export const createPayment = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
  assertCallableAuth(context);
  // assertEmailVerifiedOrThrow(context);

  const uid = context.auth.uid;
  const tenantId = String(data?.tenantId || '').trim();
  const propertyId = String(data?.propertyId || '').trim();
  const idempotencyKey = String(data?.idempotencyKey || '').trim();
  const method = normalizePaymentMethod(data?.method);
  const amount = normalizeIntegerAmount(data?.amount);

  let ownerId = null;
  let createdPaymentId = null;

  try {
    await assertPaymentsEnabledOrThrow({
      gateway: method,
      manual: method === 'manual',
    });

    await rateLimitOrThrow({
      uid,
      action: 'payment_create',
      meta: { method: method || 'unknown' },
    });

    if (!tenantId || !propertyId || !idempotencyKey || !method) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-request');
    }

    if (!Number.isInteger(amount) || amount <= 0 || amount > MAX_PAYMENT_AMOUNT_INR) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-amount');
    }

    logPaymentEvent('info', 'PAYMENT_CREATE_ATTEMPT', {
      userId: uid,
      tenantId,
      paymentId: null,
      idempotencyKey,
      amount,
      method,
      status: 'initiated',
    });

    await logPaymentIntegrityEvent('PAYMENT_ATTEMPT', {
      tenantId,
      propertyId,
      actorUid: uid,
      amount,
      method,
      idempotencyKey,
      timestamp: Date.now(),
    });

    const [tenantDoc, propertyDoc] = await Promise.all([
      db.collection('tenants').doc(tenantId).get(),
      db.collection('properties').doc(propertyId).get(),
    ]);

    if (!tenantDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'invalid-tenant');
    }
    if (!propertyDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'invalid-property');
    }

    const tenantData = tenantDoc.data() || {};
    const propertyData = propertyDoc.data() || {};
    const policy = resolveTenantOwnerLinkPolicy({
      tenantData,
      propertyData,
      propertyId,
      actorUid: uid,
      enforceOwnerActor: false,
    });
    ownerId = policy.ownerId;

    if (policy.needsTenantBackfill && uid === ownerId) {
      assertTenantBackfillProofOrThrow({
        tenantData,
        providedToken: data?.tenantLinkToken,
      });

      await tenantDoc.ref.set(
        {
          ownerId,
          propertyId,
          linkProvenAt: FieldValue.serverTimestamp(),
          ownerAssignmentTokenHash: FieldValue.delete(),
          tenantLinkTokenHash: FieldValue.delete(),
          ownerAssignmentToken: FieldValue.delete(),
          tenantLinkToken: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    if (uid !== ownerId && uid !== tenantId) {
      throw new functions.https.HttpsError('permission-denied', 'unauthorized');
    }

    const existingByIdempotency = await findPaymentByIdempotencyKey(idempotencyKey);
    if (existingByIdempotency) {
      const existingData = existingByIdempotency.data() || {};
      const existingTenantId = String(existingData.tenantId || '').trim();
      const existingOwnerId = String(existingData.ownerId || '').trim();
      const existingBaseAmount = normalizeIntegerAmount(existingData.baseAmount || existingData.amount);
      const existingMethod = String(existingData.method || '').trim().toLowerCase();

      if (
        existingTenantId !== tenantId ||
        existingOwnerId !== ownerId ||
        existingBaseAmount !== amount ||
        existingMethod !== method
      ) {
        throw new functions.https.HttpsError('failed-precondition', 'idempotency-conflict');
      }

      logPaymentEvent('info', 'IDEMPOTENCY_HIT', {
        userId: uid,
        tenantId,
        ownerId,
        paymentId: existingByIdempotency.id,
        idempotencyKey,
        amount,
        method,
        status: String(existingData.status || 'pending').toLowerCase(),
      });

      await logPaymentIntegrityEvent('IDEMPOTENCY_HIT', {
        paymentId: existingByIdempotency.id,
        tenantId,
        ownerId,
        amount,
        method,
        idempotencyKey,
        timestamp: Date.now(),
      });

      return {
        paymentId: existingByIdempotency.id,
        status: String(existingData.status || 'pending').toLowerCase(),
        idempotent: true,
      };
    }

    await blockDuplicatePaymentOrThrow({
      tenantId,
      amount,
      method,
      idempotencyKey,
    });

    const paymentRef = db.collection('payments').doc();
    const transactionRef = db.collection('transactions').doc(idempotencyKey);
    const baseAmount = amount;
    const paidAmount = method === 'manual' ? amount : 0;
    const remainingAmount = Math.max(0, baseAmount - paidAmount);
    const status = resolvePaymentStatusFromAmounts({ paidAmount, remainingAmount });

    try {
      await db.runTransaction(async (txn) => {
        const existingTx = await txn.get(transactionRef);
        if (existingTx.exists) {
          throw new functions.https.HttpsError('already-exists', 'duplicate-payment');
        }

        txn.set(paymentRef, {
          paymentId: paymentRef.id,
          tenantId,
          ownerId,
          propertyId,
          amount,
          baseAmount,
          paidAmount,
          remainingAmount,
          status,
          method,
          currency: 'INR',
          transactionId: idempotencyKey,
          idempotencyKey,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        txn.set(transactionRef, {
          transactionId: idempotencyKey,
          paymentId: paymentRef.id,
          tenantId,
          ownerId,
          propertyId,
          amount,
          status: method === 'manual' ? 'success' : 'initiated',
          gateway: method,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) {
        if (error.message === 'duplicate-payment') {
          const existing = await findPaymentByIdempotencyKey(idempotencyKey);
          if (existing) {
            const existingData = existing.data() || {};
            logPaymentEvent('info', 'IDEMPOTENCY_HIT', {
              userId: uid,
              tenantId,
              ownerId,
              paymentId: existing.id,
              idempotencyKey,
              amount,
              method,
              status: String(existingData.status || 'pending').toLowerCase(),
            });
            await logPaymentIntegrityEvent('IDEMPOTENCY_HIT', {
              paymentId: existing.id,
              tenantId,
              ownerId,
              amount,
              method,
              idempotencyKey,
              timestamp: Date.now(),
            });
            return {
              paymentId: existing.id,
              status: String(existingData.status || 'pending').toLowerCase(),
              idempotent: true,
            };
          }
        }
        throw error;
      }
      throw new functions.https.HttpsError('internal', 'internal-error');
    }

    createdPaymentId = paymentRef.id;

    await logPaymentIntegrityEvent('PAYMENT_CREATED', {
      paymentId: paymentRef.id,
      tenantId,
      ownerId,
      amount,
      method,
      idempotencyKey,
      timestamp: Date.now(),
    });

    await verifyPaymentAfterWriteOrThrow({
      paymentRef,
      tenantId,
      ownerId,
      method,
      idempotencyKey,
      amount,
    });

    logPaymentEvent('info', 'PAYMENT_SUCCESS', {
      userId: uid,
      tenantId,
      ownerId,
      paymentId: paymentRef.id,
      idempotencyKey,
      amount,
      method,
      status,
    });

    return {
      paymentId: paymentRef.id,
      status,
      idempotent: false,
    };
  } catch (error) {
    const errorCode = String(error?.code || 'internal');
    const errorMessage = error?.message || String(error);
    logPaymentEvent('error', 'PAYMENT_FAILURE', {
      userId: uid,
      tenantId,
      ownerId,
      paymentId: createdPaymentId,
      idempotencyKey,
      amount,
      method,
      status: 'failed',
      errorCode,
      errorMessage,
    });
    throw error;
  }
});

export const updatePaymentStatus = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
  assertCallableAuth(context);
  // assertEmailVerifiedOrThrow(context);

  const uid = context.auth.uid;
  const paymentId = String(data?.paymentId || '').trim();
  const requestedStatus = String(data?.newStatus || '').trim().toLowerCase();
  const installmentAmount = normalizeIntegerAmount(data?.installmentAmount);
  const installmentMethod = String(data?.installmentMethod || 'manual').trim().toLowerCase();
  const installmentNotes = String(data?.installmentNotes || '').trim();

  if (!paymentId || !['paid', 'partial', 'unpaid'].includes(requestedStatus)) {
    throw new functions.https.HttpsError('invalid-argument', 'invalid-status');
  }

  await rateLimitOrThrow({
    uid,
    action: 'payment_update_status',
    meta: { status: requestedStatus },
  });

  const paymentRef = db.collection('payments').doc(paymentId);
  const paymentDoc = await paymentRef.get();
  if (!paymentDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'payment-not-found');
  }

  const paymentData = paymentDoc.data() || {};
  const ownerId = String(paymentData.ownerId || '').trim();
  if (uid !== ownerId) {
    throw new functions.https.HttpsError('permission-denied', 'unauthorized');
  }

  const currentStatus = String(paymentData.status || '').trim().toLowerCase();
  const allowedTransitions = {
    pending: ['partial'],
    partial: ['paid'],
  };
  const allowedNext = allowedTransitions[currentStatus] || [];
  if (!allowedNext.includes(requestedStatus)) {
    throw new functions.https.HttpsError('failed-precondition', 'invalid-status-transition');
  }

  const baseAmount = normalizeIntegerAmount(paymentData.baseAmount || paymentData.amount);
  let paidAmount = normalizeIntegerAmount(paymentData.paidAmount);
  const installments = Array.isArray(paymentData.installments)
    ? [...paymentData.installments]
    : [];

  if (requestedStatus === 'partial') {
    if (installmentAmount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'invalid-amount');
    }
    const remainingBefore = Math.max(0, baseAmount - paidAmount);
    if (installmentAmount > remainingBefore) {
      throw new functions.https.HttpsError('failed-precondition', 'invalid-installment');
    }

    paidAmount += installmentAmount;
    installments.push({
      amount: installmentAmount,
      date: FieldValue.serverTimestamp(),
      method: installmentMethod || 'manual',
      notes: installmentNotes || null,
    });
  } else if (requestedStatus === 'paid') {
    const delta = Math.max(0, baseAmount - paidAmount);
    paidAmount = baseAmount;
    installments.push({
      amount: delta,
      date: FieldValue.serverTimestamp(),
      method: installmentMethod || 'manual',
      notes: installmentNotes || 'status updated to paid',
    });
  } else {
    paidAmount = 0;
    installments.length = 0;
  }

  const safePaid = Math.max(0, Math.min(baseAmount, paidAmount));
  const remainingAmount = Math.max(0, baseAmount - safePaid);
  const resolvedStatus = resolvePaymentStatusFromAmounts({
    paidAmount: safePaid,
    remainingAmount,
  });

  await paymentRef.update({
    paidAmount: safePaid,
    remainingAmount,
    status: resolvedStatus,
    installments,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await verifyPaymentAfterWriteOrThrow({
    paymentRef,
    tenantId: String(paymentData.tenantId || '').trim(),
    ownerId,
    method: String(paymentData.method || '').trim().toLowerCase() || 'manual',
    idempotencyKey: String(paymentData.idempotencyKey || '').trim(),
    amount: baseAmount,
  });

  return {
    paymentId,
    status: resolvedStatus,
    paidAmount: safePaid,
    remainingAmount,
  };
});

export const quotePayment = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);
  // assertEmailVerifiedOrThrow(context);
  await assertTenantAccessOrThrow(context.auth.uid);

  await assertPaymentsEnabledOrThrow({ gateway: data?.gateway });

  await rateLimitOrThrow({
    uid: context.auth.uid,
    action: 'payment_quote',
    limit: 10,
  });

  const leaseId = String(data?.leaseId || '').trim();
  const gateway = String(data?.gateway || 'razorpay').toLowerCase();
  if (gateway === 'cashfree') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Cashfree has been removed from this project. Use Razorpay.',
    );
  }
  const enteredRentAmountInRupees = Number(data?.enteredRentAmountInRupees || 0);

  if (!leaseId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'leaseId is required',
    );
  }

  if (enteredRentAmountInRupees < 0 || !Number.isFinite(enteredRentAmountInRupees)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'enteredRentAmountInRupees must be a positive number when provided',
    );
  }

  const paymentContext = await getLeaseOrTenantPaymentContext({
    leaseId,
    uid: context.auth.uid,
  });
  const resolvedLeaseId = paymentContext.leaseId;
  const lease = paymentContext.lease || {};
  if (lease.tenantId && !(await leaseBelongsToTenant(lease, context.auth.uid))) {
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

  const leaseRentAmount = Number(lease.rentAmount || 0);
  const baseAmount = enteredRentAmountInRupees > 0
    ? Math.round(enteredRentAmountInRupees)
    : Math.round(leaseRentAmount);

  if (!Number.isInteger(baseAmount) || baseAmount <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Calculated rent amount is invalid',
    );
  }

  const lateFeePercentage = Number(lease.lateFeePercentage || 0);
  const dueDate = toDate(lease.dueDate) || new Date();
  const isOverdue = new Date() > dueDate;
  const lateFeeAmountInRupees = isOverdue
    ? Math.round(baseAmount * (lateFeePercentage / 100))
    : 0;
  const rentAmountInRupees = baseAmount + lateFeeAmountInRupees;

  const feeConfig = await loadPaymentFeeConfig(gateway);
  const feeBreakdown = calculateFeeBreakdownInPaise({
    rentAmountInRupees,
    gatewayPercent: feeConfig.gatewayPercent,
    gstPercent: feeConfig.gstPercent,
    gatewayCostPercent: feeConfig.gatewayCostPercent,
  });

  if (feeBreakdown.convenienceFeeInPaise < feeBreakdown.estimatedGatewayCostInPaise) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configured fee is below gateway cost. Refusing quote to prevent platform loss.',
    );
  }

  return {
    leaseId: resolvedLeaseId,
    gateway,
    baseAmountInRupees: baseAmount,
    lateFeeAmountInRupees,
    rentAmountInPaise: feeBreakdown.rentAmountInPaise,
    convenienceFeeInPaise: feeBreakdown.convenienceFeeInPaise,
    totalPayableInPaise: feeBreakdown.totalPayableInPaise,
    estimatedGatewayCostInPaise: feeBreakdown.estimatedGatewayCostInPaise,
    gatewayPercent: feeConfig.gatewayPercent,
    gstPercent: feeConfig.gstPercent,
    currency: String(lease.currency || 'INR').trim() || 'INR',
    isOverdue,
  };
});

export const createPaymentIntent = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);
  // assertEmailVerifiedOrThrow(context);
  await assertTenantAccessOrThrow(context.auth.uid);

  const leaseId = String(data?.leaseId || '').trim();
  const month = Number(data.month);
  const year = Number(data.year);
  const gateway = (data.gateway || 'razorpay').toLowerCase();
  const idempotencyKey = String(data?.idempotencyKey || '').trim();

  let paymentId = null;
  let ownerId = null;
  let rentAmount = null;
  let resolvedLeaseId = leaseId;

  try {
    await assertPaymentsEnabledOrThrow({ gateway });

    await rateLimitOrThrow({
      uid: context.auth.uid,
      action: 'payment_intent',
      meta: { gateway },
    });

    if (!leaseId || !idempotencyKey) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'leaseId and idempotencyKey are required',
      );
    }

    const paymentContext = await getLeaseOrTenantPaymentContext({
      leaseId,
      uid: context.auth.uid,
    });
    resolvedLeaseId = paymentContext.leaseId;
    const lease = paymentContext.lease || {};
    if (lease.tenantId && !(await leaseBelongsToTenant(lease, context.auth.uid))) {
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

    const now = new Date();
    const requestedMonth = Number.isFinite(month) && month >= 1 && month <= 12
      ? Math.trunc(month)
      : (now.getMonth() + 1);
    const requestedYear = Number.isFinite(year) && year >= 2000 && year <= 9999
      ? Math.trunc(year)
      : now.getFullYear();

    const openPaymentSnapshot = await db
      .collection('payments')
      .where('leaseId', '==', resolvedLeaseId)
      .limit(120)
      .get();

    const openPayments = openPaymentSnapshot.docs.filter((doc) => {
      const status = String(doc.get('status') || '').trim().toLowerCase();
      return status !== 'paid' && status !== 'success';
    });

    openPayments.sort((a, b) => {
      const aDue = toDate(a.get('dueDate'));
      const bDue = toDate(b.get('dueDate'));
      if (aDue && bDue) return aDue.getTime() - bDue.getTime();

      const aYear = Number(a.get('year') || 0);
      const bYear = Number(b.get('year') || 0);
      if (aYear !== bYear) return aYear - bYear;

      const aMonth = Number(a.get('month') || 0);
      const bMonth = Number(b.get('month') || 0);
      if (aMonth !== bMonth) return aMonth - bMonth;

      return String(a.id).localeCompare(String(b.id));
    });

    let targetMonth = requestedMonth;
    let targetYear = requestedYear;
    let targetPaymentDoc = null;

    if (openPayments.length > 0) {
      targetPaymentDoc = openPayments[0];
      const openData = targetPaymentDoc.data() || {};
      const openMonth = Number(openData.month || 0);
      const openYear = Number(openData.year || 0);
      if (openMonth >= 1 && openMonth <= 12) {
        targetMonth = openMonth;
      }
      if (openYear >= 2000 && openYear <= 9999) {
        targetYear = openYear;
      }
      paymentId = targetPaymentDoc.id;
    } else {
      paymentId = `${resolvedLeaseId}_${targetYear}_${String(targetMonth).padStart(2, '0')}`;
    }

    const paymentRef = db.collection('payments').doc(paymentId);
    const transactionRef = db.collection('transactions').doc(idempotencyKey);
    const currency = String(lease.currency || 'INR').trim() || 'INR';

    const baseAmount = Number(lease.rentAmount || 0);
    const lateFeePercentage = Number(lease.lateFeePercentage || 0);
    const leaseDueDate = toDate(lease.dueDate);
    const leaseDueDay = Number(lease.rentDueDay || (leaseDueDate ? leaseDueDate.getDate() : 1) || 1);
    const resolvedCycleDueDate = dueDateFor(targetYear, targetMonth, leaseDueDay);
    const openPaymentDueDate = targetPaymentDoc
      ? toDate(targetPaymentDoc.get('dueDate'))
      : null;
    const dueDate = openPaymentDueDate || resolvedCycleDueDate;
    const isOverdue = now > dueDate;
    const lateFeeAmount = isOverdue
      ? Math.round(baseAmount * (lateFeePercentage / 100))
      : 0;
    rentAmount = baseAmount + lateFeeAmount;

    ownerId = String(lease.ownerId || '').trim();

    if (!Number.isInteger(rentAmount) || rentAmount <= 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Calculated rent amount is invalid',
      );
    }

    logPaymentEvent('info', 'PAYMENT_CREATE_ATTEMPT', {
      userId: context.auth.uid,
      tenantId: lease.tenantId || context.auth.uid,
      ownerId,
      paymentId,
      idempotencyKey,
      amount: rentAmount,
      method: gateway,
      status: 'initiated',
      extra: { leaseId: resolvedLeaseId },
    });

    await logPaymentIntegrityEvent('PAYMENT_ATTEMPT', {
      tenantId: lease.tenantId || context.auth.uid,
      ownerId: lease.ownerId || '',
      propertyId: lease.propertyId || '',
      amount: rentAmount,
      method: gateway,
      idempotencyKey,
      leaseId: resolvedLeaseId,
      timestamp: Date.now(),
    });

    const existingByIdempotency = await findPaymentByIdempotencyKey(idempotencyKey);
    if (existingByIdempotency) {
      const existingData = existingByIdempotency.data() || {};
      const existingTenantId = String(existingData.tenantId || '').trim();
      const existingLeaseId = String(existingData.leaseId || '').trim();
      const existingMethod = String(existingData.method || existingData.gateway || '').trim().toLowerCase();
      const existingBaseAmount = normalizeIntegerAmount(existingData.baseAmount || existingData.amount || existingData.rentAmount);

      if (
        existingTenantId !== String(lease.tenantId || context.auth.uid).trim() ||
        existingLeaseId !== resolvedLeaseId ||
        existingMethod !== gateway ||
        existingBaseAmount !== rentAmount
      ) {
        throw new functions.https.HttpsError('failed-precondition', 'idempotency-conflict');
      }

      logPaymentEvent('info', 'IDEMPOTENCY_HIT', {
        userId: context.auth.uid,
        tenantId: existingTenantId,
        ownerId: String(existingData.ownerId || lease.ownerId || '').trim(),
        paymentId: existingByIdempotency.id,
        idempotencyKey,
        amount: existingBaseAmount,
        method: gateway,
        status: String(existingData.status || 'pending').toLowerCase(),
        extra: { leaseId: resolvedLeaseId },
      });

      await logPaymentIntegrityEvent('IDEMPOTENCY_HIT', {
        paymentId: existingByIdempotency.id,
        tenantId: existingTenantId,
        ownerId: String(existingData.ownerId || lease.ownerId || '').trim(),
        amount: existingBaseAmount,
        method: gateway,
        idempotencyKey,
        leaseId: resolvedLeaseId,
        timestamp: Date.now(),
      });

      let resolvedOrderId = existingData.razorpayOrderId || null;
      let resolvedKeyId = existingData.razorpayKeyId || null;
      let resolvedCurrency = String(existingData.currency || 'INR');
      let resolvedAmount = Number(existingData.totalPayableInPaise || existingData.amountInPaise || 0);

      if (gateway === 'razorpay' && (!resolvedOrderId || !resolvedKeyId || resolvedAmount <= 0)) {
        const recreated = await createRazorpayOrderForPayment({
          paymentRef: existingByIdempotency.ref,
          paymentId: String(existingData.paymentId || existingByIdempotency.id).trim(),
          amountInPaise: Number(existingData.totalPayableInPaise || 0),
          currency: resolvedCurrency,
          notes: {
            paymentId: String(existingData.paymentId || existingByIdempotency.id).trim(),
            tenantId: existingTenantId,
            propertyId: String(existingData.propertyId || lease.propertyId || '').trim(),
            ownerId: String(existingData.ownerId || lease.ownerId || '').trim(),
          },
        });
        resolvedOrderId = recreated.orderId;
        resolvedKeyId = recreated.keyId;
        resolvedCurrency = recreated.currency;
        resolvedAmount = recreated.amount;
      }

      return {
        paymentId: String(existingData.paymentId || existingByIdempotency.id).trim(),
        gateway,
        amount: gateway === 'razorpay'
          ? resolvedAmount
          : (Number(existingData.totalPayableInPaise || existingData.amountInPaise || 0) / 100),
        rentAmountInPaise: Number(existingData.rentAmountInPaise || 0),
        convenienceFeeInPaise: Number(existingData.convenienceFeeInPaise || 0),
        totalPayableInPaise: Number(existingData.totalPayableInPaise || 0),
        estimatedGatewayCostInPaise: Number(existingData.estimatedGatewayCostInPaise || 0),
        gatewayPercent: Number(existingData.gatewayPercent || 0),
        gstPercent: Number(existingData.gstPercent || 0),
        currency: resolvedCurrency,
        idempotencyKey,
        orderId: resolvedOrderId,
        clientSecret: existingData.stripeClientSecret || null,
        keyId: resolvedKeyId,
      };
    }

    await blockDuplicatePaymentOrThrow({
      tenantId: String(lease.tenantId || context.auth.uid).trim(),
      amount: rentAmount,
      method: gateway,
      idempotencyKey,
    });

    const feeConfig = await loadPaymentFeeConfig(gateway);
    const feeBreakdown = calculateFeeBreakdownInPaise({
      rentAmountInRupees: rentAmount,
      gatewayPercent: feeConfig.gatewayPercent,
      gstPercent: feeConfig.gstPercent,
      gatewayCostPercent: feeConfig.gatewayCostPercent,
    });

    if (feeBreakdown.convenienceFeeInPaise < feeBreakdown.estimatedGatewayCostInPaise) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Configured fee is below gateway cost. Refusing payment intent to prevent platform loss.',
      );
    }

    const totalAmount = feeBreakdown.totalPayableInPaise / 100;

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
      logPaymentEvent('info', 'IDEMPOTENCY_HIT', {
        userId: context.auth.uid,
        tenantId: lease.tenantId || context.auth.uid,
        ownerId: lease.ownerId || '',
        paymentId,
        idempotencyKey,
        amount: rentAmount,
        method: gateway,
        status: String(payment.get('status') || 'pending').toLowerCase(),
        extra: { leaseId: resolvedLeaseId },
      });
      await logPaymentIntegrityEvent('IDEMPOTENCY_HIT', {
        paymentId,
        tenantId: lease.tenantId || context.auth.uid,
        ownerId: lease.ownerId || '',
        amount: rentAmount,
        method: gateway,
        idempotencyKey,
        leaseId: resolvedLeaseId,
        timestamp: Date.now(),
      });
      const storedTotalPayableInPaise = Number(payment.get('totalPayableInPaise') || 0);
      const storedRentAmountInPaise = Number(payment.get('rentAmountInPaise') || 0);
      const storedFeeInPaise = Number(payment.get('convenienceFeeInPaise') || 0);
      let resolvedOrderId = payment.get('razorpayOrderId') || null;
      let resolvedKeyId = payment.get('razorpayKeyId') || null;
      let resolvedCurrency = payment.get('currency') || currency;
      let resolvedAmountInPaise = (storedTotalPayableInPaise || feeBreakdown.totalPayableInPaise);

      if (gateway === 'razorpay' && (!resolvedOrderId || !resolvedKeyId || resolvedAmountInPaise <= 0)) {
        const recreated = await createRazorpayOrderForPayment({
          paymentRef,
          paymentId,
          amountInPaise: storedTotalPayableInPaise || feeBreakdown.totalPayableInPaise,
          currency: resolvedCurrency,
          notes: {
            paymentId,
            tenantId: String(lease.tenantId || context.auth.uid).trim(),
            propertyId: String(lease.propertyId || '').trim(),
            ownerId: String(lease.ownerId || '').trim(),
          },
        });
        resolvedOrderId = recreated.orderId;
        resolvedKeyId = recreated.keyId;
        resolvedCurrency = recreated.currency;
        resolvedAmountInPaise = recreated.amount;
      }

      return {
        paymentId,
        gateway,
        amount: gateway === 'razorpay'
          ? resolvedAmountInPaise
          : ((storedTotalPayableInPaise || feeBreakdown.totalPayableInPaise) / 100),
        rentAmountInPaise: storedRentAmountInPaise || feeBreakdown.rentAmountInPaise,
        convenienceFeeInPaise: storedFeeInPaise || feeBreakdown.convenienceFeeInPaise,
        totalPayableInPaise: storedTotalPayableInPaise || feeBreakdown.totalPayableInPaise,
        estimatedGatewayCostInPaise: Number(
          payment.get('estimatedGatewayCostInPaise') || feeBreakdown.estimatedGatewayCostInPaise,
        ),
        gatewayPercent: Number(payment.get('gatewayPercent') || feeConfig.gatewayPercent),
        gstPercent: Number(payment.get('gstPercent') || feeConfig.gstPercent),
        currency: resolvedCurrency,
        idempotencyKey,
        orderId: resolvedOrderId,
        clientSecret: payment.get('stripeClientSecret') || null,
        keyId: resolvedKeyId,
      };
    }

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

      const txSnap = await t.get(transactionRef);
      if (txSnap.exists) {
        throw new functions.https.HttpsError('already-exists', 'duplicate-payment');
      }

      t.set(
        paymentRef,
        {
          paymentId,
          leaseId: resolvedLeaseId,
          tenantId: lease.tenantId || context.auth.uid,
          ownerId: lease.ownerId || '',
          propertyId: lease.propertyId || '',
          month: targetMonth,
          year: targetYear,
          dueDate,
          baseAmount,
          lateFeeAmount,
          rentAmount,
          rentAmountInPaise: feeBreakdown.rentAmountInPaise,
          convenienceFeeInPaise: feeBreakdown.convenienceFeeInPaise,
          totalPayableInPaise: feeBreakdown.totalPayableInPaise,
          estimatedGatewayCostInPaise: feeBreakdown.estimatedGatewayCostInPaise,
          gatewayPercent: feeConfig.gatewayPercent,
          gatewayCostPercent: feeConfig.gatewayCostPercent,
          gstPercent: feeConfig.gstPercent,
          totalAmount,
          status: 'pending',
          method: gateway,
          gateway,
          currency,
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
        leaseId: resolvedLeaseId,
        tenantId: lease.tenantId || context.auth.uid,
        ownerId: lease.ownerId || '',
        amount: totalAmount,
        rentAmountInPaise: feeBreakdown.rentAmountInPaise,
        convenienceFeeInPaise: feeBreakdown.convenienceFeeInPaise,
        totalPayableInPaise: feeBreakdown.totalPayableInPaise,
        estimatedGatewayCostInPaise: feeBreakdown.estimatedGatewayCostInPaise,
        currency: lease.currency || 'INR',
        status: 'initiated',
        gateway,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    await logPaymentIntegrityEvent('PAYMENT_CREATED', {
      paymentId,
      tenantId: lease.tenantId || context.auth.uid,
      ownerId: lease.ownerId || '',
      propertyId: lease.propertyId || '',
      amount: rentAmount,
      method: gateway,
      idempotencyKey,
      leaseId: resolvedLeaseId,
      timestamp: Date.now(),
    });

    await verifyPaymentAfterWriteOrThrow({
      paymentRef,
      tenantId: String(lease.tenantId || context.auth.uid).trim(),
      ownerId: String(lease.ownerId || '').trim(),
      method: gateway,
      idempotencyKey,
      amount: rentAmount,
    });

    if (gateway === 'razorpay') {
      const recreated = await createRazorpayOrderForPayment({
        paymentRef,
        paymentId,
        amountInPaise: feeBreakdown.totalPayableInPaise,
        currency,
        notes: { paymentId },
      });

      return {
        paymentId,
        gateway: 'razorpay',
        amount: recreated.amount,
        rentAmountInPaise: feeBreakdown.rentAmountInPaise,
        convenienceFeeInPaise: feeBreakdown.convenienceFeeInPaise,
        totalPayableInPaise: feeBreakdown.totalPayableInPaise,
        estimatedGatewayCostInPaise: feeBreakdown.estimatedGatewayCostInPaise,
        gatewayPercent: feeConfig.gatewayPercent,
        gstPercent: feeConfig.gstPercent,
        currency: recreated.currency,
        idempotencyKey,
        orderId: recreated.orderId,
        keyId: recreated.keyId,
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
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cashfree has been removed from this project. Use Razorpay.',
      );
    }

    throw new functions.https.HttpsError(
      'invalid-argument',
      'Unsupported payment gateway',
    );
  } catch (error) {
    const errorCode = String(error?.code || 'internal');
    const errorMessage = error?.message || String(error);
    logPaymentEvent('error', 'PAYMENT_FAILURE', {
      userId: context.auth.uid,
      tenantId: null,
      ownerId,
      paymentId,
      idempotencyKey,
      amount: rentAmount,
      method: gateway,
      status: 'failed',
      errorCode,
      errorMessage,
      extra: { leaseId: resolvedLeaseId },
    });
    throw error;
  }
});

export const verifyPayment = functions.https.onCall(async (data, context) => {
  assertCallableAuth(context);
  // assertEmailVerifiedOrThrow(context);
  await assertTenantAccessOrThrow(context.auth.uid);

  const paymentId = data.paymentId;
  const gateway = (data.gateway || '').toLowerCase();
  const payload = data.payload || {};

  let tenantId = null;
  let ownerId = null;
  let amount = null;
  let idempotencyKey = null;

  try {
    await rateLimitOrThrow({
      uid: context.auth.uid,
      action: 'payment_verify',
      meta: { gateway },
    });
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
    tenantId = String(payment.tenantId || '').trim();
    ownerId = String(payment.ownerId || '').trim();
    amount = normalizeIntegerAmount(payment.baseAmount || payment.rentAmount || payment.amount);
    idempotencyKey = String(payment.idempotencyKey || payment.transactionId || '').trim();

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
      logPaymentEvent('info', 'PAYMENT_SUCCESS', {
        userId: context.auth.uid,
        tenantId,
        ownerId,
        paymentId,
        idempotencyKey,
        amount,
        method: gateway,
        status: 'paid',
      });
      return { ok: true };
    }

    if (gateway === 'razorpay') {
      const { keySecret, mode } = getRazorpayConfig();
      if (!keySecret) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Razorpay secret not configured for mode=${mode}`,
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

      const finalized = await db.runTransaction(async (t) => {
        const txSnap = await t.get(transactionRef);
        if (txSnap.exists && txSnap.get('status') === 'success') return false;

        const rentAmountInPaise = Number(payment.rentAmountInPaise || (Number(payment.rentAmount || payment.baseAmount || payment.amount || 0) * 100));
        const convenienceFeeInPaise = Number(payment.convenienceFeeInPaise || 0);
        const totalPayableInPaise = Number(payment.totalPayableInPaise || payment.amountInPaise || (rentAmountInPaise + convenienceFeeInPaise));
        const estimatedGatewayCostInPaise = Number(payment.estimatedGatewayCostInPaise || convenienceFeeInPaise);

        t.set(
          paymentRef,
          {
            status: 'paid',
            method: 'razorpay',
            transactionId: transactionId,
            razorpayOrderId,
            paidAmount: Math.trunc(rentAmountInPaise / 100),
            paidRentAmountInPaise: rentAmountInPaise,
            paidConvenienceFeeInPaise: convenienceFeeInPaise,
            collectedAmountInPaise: totalPayableInPaise,
            paidAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        t.set(
          transactionRef,
          {
            status: 'success',
            amount: totalPayableInPaise / 100,
            rentAmountInPaise,
            convenienceFeeInPaise,
            totalPayableInPaise,
            estimatedGatewayCostInPaise,
            gatewayResponse: {
              razorpayPaymentId,
              razorpayOrderId,
            },
            verificationSignature: razorpaySignature,
            completedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        return true;
      });

      if (finalized) {
        await incrementFeeAnalytics({
          gateway: 'razorpay',
          rentAmountInPaise: Number(payment.rentAmountInPaise || (Number(payment.rentAmount || payment.baseAmount || payment.amount || 0) * 100)),
          convenienceFeeInPaise: Number(payment.convenienceFeeInPaise || 0),
          totalPayableInPaise: Number(payment.totalPayableInPaise || payment.amountInPaise || ((Number(payment.rentAmount || payment.baseAmount || payment.amount || 0) * 100) + Number(payment.convenienceFeeInPaise || 0))),
          estimatedGatewayCostInPaise: Number(payment.estimatedGatewayCostInPaise || payment.convenienceFeeInPaise || 0),
        });

        await verifyPaymentAfterWriteOrThrow({
          paymentRef,
          tenantId: String(payment.tenantId || '').trim(),
          ownerId: String(payment.ownerId || '').trim(),
          method: 'razorpay',
          idempotencyKey: String(payment.idempotencyKey || payment.transactionId || '').trim(),
          amount: normalizeIntegerAmount(payment.baseAmount || payment.rentAmount || payment.amount),
        });
      }

      logPaymentEvent('info', 'PAYMENT_SUCCESS', {
        userId: context.auth.uid,
        tenantId,
        ownerId,
        paymentId,
        idempotencyKey,
        amount,
        method: gateway,
        status: 'paid',
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
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cashfree has been removed from this project. Use Razorpay.',
      );
    }

    throw new functions.https.HttpsError(
      'invalid-argument',
      'Unsupported payment gateway',
    );
  } catch (error) {
    const errorCode = String(error?.code || 'internal');
    const errorMessage = error?.message || String(error);
    logPaymentEvent('error', 'PAYMENT_FAILURE', {
      userId: context.auth.uid,
      tenantId,
      ownerId,
      paymentId,
      idempotencyKey,
      amount,
      method: gateway,
      status: 'failed',
      errorCode,
      errorMessage,
    });
    throw error;
  }
});

// ==========================================================
// ADMIN DISASTER CONTROL + RECOVERY
// ==========================================================

export const togglePayments = functions.region('asia-south1').https.onCall(async (data, context) => {
  assertCallableAuth(context);
  await assertAdminAccessOrThrow(context.auth.uid);

  const enabled = data?.enabled;
  const reason = String(data?.reason || '').trim();
  if (typeof enabled !== 'boolean') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'enabled must be a boolean',
    );
  }

  const ref = db.collection('appConfig').doc('global');
  const current = await ref.get();
  const previousValue = current.exists ? current.data() : null;

  await ref.set(
    {
      paymentsEnabled: enabled,
      lastUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await logAdminAudit({
    action: 'toggle_payments',
    adminId: context.auth.uid,
    targetId: 'appConfig/global',
    oldValue: previousValue,
    newValue: { paymentsEnabled: enabled },
    reason: reason || null,
  });

  return { ok: true, paymentsEnabled: enabled };
});

export const deletePayment = functions.region('asia-south1').https.onCall(async (data, context) => {
  assertCallableAuth(context);
  await assertAdminAccessOrThrow(context.auth.uid);

  const paymentId = String(data?.paymentId || '').trim();
  const reason = String(data?.reason || '').trim();
  if (!paymentId || !reason) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'paymentId and reason are required',
    );
  }

  const paymentRef = db.collection('payments').doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Payment not found');
  }

  const payment = paymentSnap.data() || {};

  await paymentRef.set(
    {
      status: 'deleted',
      isDeleted: true,
      deletedAt: FieldValue.serverTimestamp(),
      deletedBy: context.auth.uid,
      deleteReason: reason,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const transactionId = String(payment.transactionId || '').trim();
  if (transactionId) {
    await db.collection('transactions').doc(transactionId).set(
      {
        status: 'void',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await logAdminAudit({
    action: 'delete_payment',
    adminId: context.auth.uid,
    targetId: paymentId,
    oldValue: payment,
    newValue: {
      status: 'deleted',
      isDeleted: true,
      deletedBy: context.auth.uid,
    },
    reason,
  });

  return { ok: true };
});

export const correctPayment = functions.region('asia-south1').https.onCall(async (data, context) => {
  assertCallableAuth(context);
  await assertAdminAccessOrThrow(context.auth.uid);

  const paymentId = String(data?.paymentId || '').trim();
  const updates = data?.updates || {};
  const reason = String(data?.reason || '').trim();
  if (!paymentId || !reason || typeof updates !== 'object') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'paymentId, updates, and reason are required',
    );
  }

  const paymentRef = db.collection('payments').doc(paymentId);
  let oldValue = null;
  let newValue = null;

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(paymentRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment not found');
    }

    const payment = snap.data() || {};
    oldValue = payment;

    const baseAmount = normalizeIntegerAmount(
      payment.baseAmount || payment.rentAmount || payment.amount,
    );
    const paidAmountRaw = updates.paidAmount ?? payment.paidAmount ?? 0;
    const remainingAmountRaw = updates.remainingAmount ?? (baseAmount - paidAmountRaw);
    const paidAmount = normalizeIntegerAmount(paidAmountRaw);
    const remainingAmount = normalizeIntegerAmount(remainingAmountRaw);

    if (paidAmount < 0 || remainingAmount < 0 || (paidAmount + remainingAmount) !== baseAmount) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid payment correction values',
      );
    }

    const status = updates.status
      ? String(updates.status).trim().toLowerCase()
      : resolvePaymentStatusFromAmounts({ paidAmount, remainingAmount });

    newValue = {
      paidAmount,
      remainingAmount,
      status,
      correctedBy: context.auth.uid,
      correctionReason: reason,
      correctedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    txn.set(paymentRef, newValue, { merge: true });
  });

  await logAdminAudit({
    action: 'correct_payment',
    adminId: context.auth.uid,
    targetId: paymentId,
    oldValue,
    newValue,
    reason,
  });

  return { ok: true };
});

export const recalculateTenantBalance = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
  assertCallableAuth(context);
  await assertAdminAccessOrThrow(context.auth.uid);

  const tenantId = String(data?.tenantId || '').trim();
  if (!tenantId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'tenantId is required',
    );
  }

  const paymentsSnap = await db
    .collection('payments')
    .where('tenantId', '==', tenantId)
    .get();

  let totalPaid = 0;
  let totalRemaining = 0;
  let lastPaymentAt = null;

  paymentsSnap.forEach((doc) => {
    const payment = doc.data() || {};
    if (payment.isDeleted === true || String(payment.status || '').toLowerCase() === 'deleted') {
      return;
    }

    const baseAmount = normalizeIntegerAmount(payment.baseAmount || payment.rentAmount || payment.amount);
    const paidAmount = normalizeIntegerAmount(payment.paidAmount || 0);
    const remainingAmount = normalizeIntegerAmount(payment.remainingAmount || Math.max(0, baseAmount - paidAmount));

    const paid = paidAmount > 0 ? paidAmount : (String(payment.status || '').toLowerCase() === 'paid' ? baseAmount : 0);
    totalPaid += paid;
    totalRemaining += Math.max(0, remainingAmount);

    const paidAt = toDate(payment.paidAt) || toDate(payment.updatedAt) || toDate(payment.createdAt);
    if (paidAt && (!lastPaymentAt || paidAt > lastPaymentAt)) {
      lastPaymentAt = paidAt;
    }
  });

  await db.collection('tenants').doc(tenantId).set(
    {
      totalPaidAmount: totalPaid,
      totalRemainingAmount: totalRemaining,
      balanceUpdatedAt: FieldValue.serverTimestamp(),
      lastPaymentAt: lastPaymentAt ? Timestamp.fromDate(lastPaymentAt) : null,
    },
    { merge: true },
  );

  await logAdminAudit({
    action: 'recalculate_tenant_balance',
    adminId: context.auth.uid,
    targetId: tenantId,
    newValue: { totalPaid, totalRemaining },
    reason: 'recalculate',
  });

  return { ok: true, totalPaid, totalRemaining };
});

// ==========================================================
// OWNER RAZORPAY PAYMENT INTENT + VERIFICATION
// ==========================================================

export const quoteOwnerRazorpayPayment = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  await assertOwnerAccessOrThrow(ownerId);

  const amount = Number(data?.amount || 0);
  if (!Number.isInteger(amount) || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'amount must be a positive integer in rupees',
    );
  }

  if (amount > 5000000) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Amount exceeds allowed maximum',
    );
  }

  const feeConfig = await loadPaymentFeeConfig('razorpay');
  const quote = calculateFeeBreakdownInPaise({
    rentAmountInRupees: amount,
    gatewayPercent: feeConfig.gatewayPercent,
    gstPercent: feeConfig.gstPercent,
    gatewayCostPercent: feeConfig.gatewayCostPercent,
  });

  if (quote.convenienceFeeInPaise < quote.estimatedGatewayCostInPaise) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configured fee is below gateway cost. Refusing payment intent to prevent platform loss.',
    );
  }

  return {
    rentAmountInPaise: quote.rentAmountInPaise,
    convenienceFeeInPaise: quote.convenienceFeeInPaise,
    totalPayableInPaise: quote.totalPayableInPaise,
    gatewayPercent: feeConfig.gatewayPercent,
    gstPercent: feeConfig.gstPercent,
  };
});

export const createOwnerRazorpayPaymentIntent = functions.region('asia-south1').https.onCall(async (data, context) => {
  assertCallableAuth(context);

  const ownerId = context.auth.uid;
  await assertOwnerAccessOrThrow(ownerId);

  await assertPaymentsEnabledOrThrow({ gateway: 'razorpay' });

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

  await logPaymentIntegrityEvent('PAYMENT_ATTEMPT', {
    tenantId,
    propertyId,
    actorUid: ownerId,
    ownerId,
    amount,
    method: 'razorpay',
    idempotencyKey,
    timestamp: Date.now(),
  });

  const feeConfig = await loadPaymentFeeConfig('razorpay');
  const feeBreakdown = calculateFeeBreakdownInPaise({
    rentAmountInRupees: amount,
    gatewayPercent: feeConfig.gatewayPercent,
    gstPercent: feeConfig.gstPercent,
    gatewayCostPercent: feeConfig.gatewayCostPercent,
  });

  if (feeBreakdown.convenienceFeeInPaise < feeBreakdown.estimatedGatewayCostInPaise) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Configured fee is below gateway cost. Refusing payment intent to prevent platform loss.',
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

  const policy = resolveTenantOwnerLinkPolicy({
    tenantData,
    propertyData,
    propertyId,
    actorUid: ownerId,
    enforceOwnerActor: true,
  });

  if (policy.needsTenantBackfill) {
    assertTenantBackfillProofOrThrow({
      tenantData,
      providedToken: data?.tenantLinkToken,
    });

    await tenantRef.set(
      {
        ownerId,
        propertyId,
        linkProvenAt: FieldValue.serverTimestamp(),
        ownerAssignmentTokenHash: FieldValue.delete(),
        tenantLinkTokenHash: FieldValue.delete(),
        ownerAssignmentToken: FieldValue.delete(),
        tenantLinkToken: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  const existingByIdempotency = await findPaymentByIdempotencyKey(idempotencyKey);
  if (existingByIdempotency) {
    const existingData = existingByIdempotency.data() || {};
    const existingTenantId = String(existingData.tenantId || '').trim();
    const existingOwnerId = String(existingData.ownerId || '').trim();
    const existingPropertyId = String(existingData.propertyId || '').trim();
    const existingMethod = String(existingData.method || '').trim().toLowerCase();
    const existingAmount = normalizeIntegerAmount(existingData.baseAmount || existingData.amount);

    if (
      existingTenantId !== tenantId ||
      existingOwnerId !== ownerId ||
      existingPropertyId !== propertyId ||
      existingMethod !== 'razorpay' ||
      existingAmount !== amount
    ) {
      throw new functions.https.HttpsError('failed-precondition', 'idempotency-conflict');
    }

    await logPaymentIntegrityEvent('IDEMPOTENCY_HIT', {
      paymentId: existingByIdempotency.id,
      tenantId,
      ownerId,
      propertyId,
      amount,
      method: 'razorpay',
      idempotencyKey,
      timestamp: Date.now(),
    });

    return {
      paymentId: String(existingData.paymentId || existingByIdempotency.id).trim(),
      gateway: 'razorpay',
      amountInPaise: Number(
        existingData.amountInPaise
          || existingData.totalPayableInPaise
          || feeBreakdown.totalPayableInPaise,
      ),
      rentAmountInPaise: Number(
        existingData.rentAmountInPaise || feeBreakdown.rentAmountInPaise,
      ),
      convenienceFeeInPaise: Number(
        existingData.convenienceFeeInPaise || feeBreakdown.convenienceFeeInPaise,
      ),
      totalPayableInPaise: Number(
        existingData.totalPayableInPaise || feeBreakdown.totalPayableInPaise,
      ),
      currency: String(existingData.currency || currency),
      idempotencyKey,
      orderId: existingData.razorpayOrderId || null,
      keyId: existingData.razorpayKeyId || null,
    };
  }

  await blockDuplicatePaymentOrThrow({
    tenantId,
    amount,
    method: 'razorpay',
    idempotencyKey,
  });

  const existingTransaction = await transactionRef.get();
  if (existingTransaction.exists) {
    const existingPaymentId = String(existingTransaction.get('paymentId') || '').trim();
    if (existingPaymentId) {
      const existingPayment = await db.collection('payments').doc(existingPaymentId).get();
      if (existingPayment.exists) {
        await logPaymentIntegrityEvent('IDEMPOTENCY_HIT', {
          paymentId: existingPaymentId,
          tenantId,
          ownerId,
          propertyId,
          amount,
          method: 'razorpay',
          idempotencyKey,
          timestamp: Date.now(),
        });
        return {
          paymentId: existingPaymentId,
          gateway: 'razorpay',
          amountInPaise: Number(
            existingPayment.get('amountInPaise')
              || existingPayment.get('totalPayableInPaise')
              || feeBreakdown.totalPayableInPaise,
          ),
          rentAmountInPaise: Number(
            existingPayment.get('rentAmountInPaise') || feeBreakdown.rentAmountInPaise,
          ),
          convenienceFeeInPaise: Number(
            existingPayment.get('convenienceFeeInPaise') || feeBreakdown.convenienceFeeInPaise,
          ),
          totalPayableInPaise: Number(
            existingPayment.get('totalPayableInPaise') || feeBreakdown.totalPayableInPaise,
          ),
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
  const amountInPaise = feeBreakdown.totalPayableInPaise;

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
      rentAmountInPaise: feeBreakdown.rentAmountInPaise,
      convenienceFeeInPaise: feeBreakdown.convenienceFeeInPaise,
      totalPayableInPaise: feeBreakdown.totalPayableInPaise,
      estimatedGatewayCostInPaise: feeBreakdown.estimatedGatewayCostInPaise,
      gatewayPercent: feeConfig.gatewayPercent,
      gatewayCostPercent: feeConfig.gatewayCostPercent,
      gstPercent: feeConfig.gstPercent,
      status: 'pending',
      method: 'razorpay',
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
      amount: feeBreakdown.totalPayableInPaise / 100,
      rentAmountInPaise: feeBreakdown.rentAmountInPaise,
      convenienceFeeInPaise: feeBreakdown.convenienceFeeInPaise,
      totalPayableInPaise: feeBreakdown.totalPayableInPaise,
      estimatedGatewayCostInPaise: feeBreakdown.estimatedGatewayCostInPaise,
      currency,
      gateway: 'razorpay',
      status: 'initiated',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await logPaymentIntegrityEvent('PAYMENT_CREATED', {
    paymentId,
    tenantId,
    ownerId,
    propertyId,
    amount,
    method: 'razorpay',
    idempotencyKey,
    timestamp: Date.now(),
  });

  await verifyPaymentAfterWriteOrThrow({
    paymentRef,
    tenantId,
    ownerId,
    method: 'razorpay',
    idempotencyKey,
    amount,
  });

  const { keyId, keySecret, mode, keyPrefixMismatch } = getRazorpayConfig();
  if (keyPrefixMismatch) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay mode-key mismatch: mode=${mode}`,
    );
  }
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay keys not configured for mode=${mode}`,
    );
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
    rentAmountInPaise: feeBreakdown.rentAmountInPaise,
    convenienceFeeInPaise: feeBreakdown.convenienceFeeInPaise,
    totalPayableInPaise: feeBreakdown.totalPayableInPaise,
    currency: order.currency,
    idempotencyKey,
    orderId: order.id,
    keyId,
  };
});

export const verifyOwnerRazorpayPayment = functions.region('asia-south1').https.onCall(async (data, context) => {
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

  const { keyId, keySecret, mode, keyPrefixMismatch } = getRazorpayConfig();
  if (keyPrefixMismatch) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay mode-key mismatch: mode=${mode}`,
    );
  }
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay secret not configured for mode=${mode}`,
    );
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

  const finalized = await db.runTransaction(async (txn) => {
    const latestPayment = await txn.get(paymentRef);
    if (latestPayment.exists && String(latestPayment.get('status') || '').toLowerCase() === 'paid') {
      return false;
    }

    const rentAmountInPaise = Number(payment.rentAmountInPaise || (Number(payment.amount || 0) * 100));
    const convenienceFeeInPaise = Number(payment.convenienceFeeInPaise || 0);
    const totalPayableInPaise = Number(
      payment.totalPayableInPaise
        || payment.amountInPaise
        || (rentAmountInPaise + convenienceFeeInPaise),
    );
    const estimatedGatewayCostInPaise = Number(payment.estimatedGatewayCostInPaise || convenienceFeeInPaise);

    txn.set(paymentRef, {
      status: 'paid',
      method: 'razorpay',
      paidAmount: Number(payment.amount || 0),
      remainingAmount: 0,
      collectedAmountInPaise: totalPayableInPaise,
      paidRentAmountInPaise: rentAmountInPaise,
      paidConvenienceFeeInPaise: convenienceFeeInPaise,
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
      amount: totalPayableInPaise / 100,
      rentAmountInPaise,
      convenienceFeeInPaise,
      totalPayableInPaise,
      estimatedGatewayCostInPaise,
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

    return true;
  });

  if (finalized) {
    await incrementFeeAnalytics({
      gateway: 'razorpay',
      rentAmountInPaise: Number(payment.rentAmountInPaise || (Number(payment.amount || 0) * 100)),
      convenienceFeeInPaise: Number(payment.convenienceFeeInPaise || 0),
      totalPayableInPaise: Number(
        payment.totalPayableInPaise
          || payment.amountInPaise
          || ((Number(payment.amount || 0) * 100) + Number(payment.convenienceFeeInPaise || 0)),
      ),
      estimatedGatewayCostInPaise: Number(
        payment.estimatedGatewayCostInPaise || payment.convenienceFeeInPaise || 0,
      ),
    });

    await verifyPaymentAfterWriteOrThrow({
      paymentRef,
      tenantId: String(payment.tenantId || '').trim(),
      ownerId,
      method: 'razorpay',
      idempotencyKey: String(payment.idempotencyKey || payment.transactionId || '').trim(),
      amount: normalizeIntegerAmount(payment.baseAmount || payment.amount),
    });
  }

  return {
    ok: true,
    paymentId,
    transactionId: transactionId || `rzp_${paymentId}`,
  };
});

// ==========================================================
// OWNER SUBSCRIPTION
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
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

export const ensureOwnerSubscriptionProfile = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
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

export const getOwnerSubscriptionSnapshot = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
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
  } else {
    const current = ownerDoc.data() || {};
    if (email && current.email !== email) {
      await ownerRef.set({ email, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
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
    paymentOrderId: finalData.paymentOrderId || finalData.cashfreeOrderId || null,
    paymentSubscriptionId: finalData.paymentSubscriptionId || finalData.cashfreeSubscriptionId || null,
  };
});

export const activateOwnerFreeSubscription = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
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

export const createOwnerSubscriptionPaymentIntent = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
  throw new functions.https.HttpsError(
    'failed-precondition',
    'Cashfree subscription flow has been removed from this project.',
  );
});

export const verifyOwnerSubscriptionPayment = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
  throw new functions.https.HttpsError(
    'failed-precondition',
    'Cashfree subscription flow has been removed from this project.',
  );
});

function trustStatusLabel(score) {
  const clamped = Math.max(0, Math.min(100, Number(score) || 0));
  if (clamped >= 80) return 'Highly Trusted';
  if (clamped >= 60) return 'Reliable';
  if (clamped >= 40) return 'Average Risk';
  if (clamped >= 20) return 'High Risk';
  return 'Very Risky Tenant';
}

export const lookupTenantTrustScore = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
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

export const createRazorpayOrder = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
  assertCallableAuth(context);
  await assertTenantAccessOrThrow(context.auth.uid);

  const { keyId, keySecret, mode, keyPrefixMismatch } = getRazorpayConfig();
  if (keyPrefixMismatch) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay mode-key mismatch: mode=${mode}`,
    );
  }
  if (!keyId || !keySecret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Razorpay keys not configured for mode=${mode}`,
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

export const confirmRazorpayPayment = functions.region('asia-south1')
  .https.onCall(
  async (data, context) => {
    assertCallableAuth(context);
    await assertTenantAccessOrThrow(context.auth.uid);

    const { keySecret, mode } = getRazorpayConfig();
    if (!keySecret) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Razorpay secret not configured for mode=${mode}`,
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

export const deleteOwnerPropertyCascade = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
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

export const linkTenantAccount = functions.region('asia-south1')
  .https.onCall(async (data, context) => {
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

export const razorpayWebhook = functions.region('asia-south1')
  .https.onRequest(async (req, res) => {
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
      const notes = paymentEntity?.notes || payload?.order?.entity?.notes || {};
      await db.collection('messages').doc(`${paymentId}_failed`).set({
        type: 'reminder',
        title: 'Payment failed',
        body: `Razorpay payment failed (${paymentEntity?.error_description || 'unknown reason'}).`,
        severity: 'warn',
        paymentId,
        tenantId: notes.tenantId || null,
        ownerId: notes.ownerId || null,
        createdAt: FieldValue.serverTimestamp(),
        read: false,
      });
    }
  }

  res.json({ received: true });
});

export const stripeWebhook = functions.region('asia-south1')
  .https.onRequest(async (req, res) => {
  res.status(501).send('Stripe webhook not configured');
});

