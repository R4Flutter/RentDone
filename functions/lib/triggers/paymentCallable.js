"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyTenantSubscriptionPayment = exports.createTenantSubscriptionPaymentIntent = exports.verifyOwnerSubscriptionPayment = exports.createOwnerSubscriptionPaymentIntent = exports.activateOwnerFreeSubscription = exports.getOwnerSubscriptionSnapshot = exports.ensureOwnerSubscriptionProfile = exports.updatePaymentStatus = exports.confirmRazorpayPayment = exports.verifyPayment = exports.verifyOwnerRazorpayPayment = exports.createPayment = exports.createPaymentIntent = exports.createOwnerRazorpayPaymentIntent = exports.quotePayment = exports.quoteOwnerRazorpayPayment = exports.razorpayPaymentWebhook = void 0;
const node_crypto_1 = require("node:crypto");
const https_1 = require("firebase-functions/v2/https");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../utils/logger");
const paymentService_1 = require("../services/paymentService");
const criticalGuards_1 = require("../security/criticalGuards");
const REGION = "asia-south1";
const MIN_PAYMENT_AMOUNT = 1;
const MAX_PAYMENT_AMOUNT = 5_000_000;
const DEFAULT_CURRENCY = "INR";
const MAX_WEBHOOK_RAW_BODY_BYTES = 256_000;
const PAYMENT_COLLECTION = "payments";
const OWNER_SUBSCRIPTION_COLLECTION = "ownerSubscriptionPayments";
const TENANT_SUBSCRIPTION_COLLECTION = "tenantSubscriptionPayments";
const GATEWAY_PERCENT = 2;
const GST_PERCENT = 18;
const OWNER_SUBSCRIPTION_PLANS = {
    basic: {
        code: "basic",
        title: "Basic",
        monthlyPriceInRupees: 99,
        tenantLimit: 10,
    },
    pro: {
        code: "pro",
        title: "Pro",
        monthlyPriceInRupees: 499,
        tenantLimit: 50,
    },
};
const TENANT_SUBSCRIPTION_PLANS = {
    ad_free_1m: {
        code: "ad_free_1m",
        title: "Ad Free - 1 Month",
        priceInRupees: 29,
        durationDays: 30,
    },
    ad_free_2m: {
        code: "ad_free_2m",
        title: "Ad Free - 2 Months",
        priceInRupees: 49,
        durationDays: 60,
    },
};
const ABUSE_LIMITS = {
    payment_create: { user: 8, app: 20, ip: 25 },
    payment_verify: { user: 12, app: 30, ip: 35 },
    owner_subscription_create: { user: 4, app: 12, ip: 15 },
    owner_subscription_verify: { user: 6, app: 16, ip: 18 },
    tenant_subscription_create: { user: 4, app: 12, ip: 15 },
    tenant_subscription_verify: { user: 6, app: 16, ip: 18 },
};
const asString = (value) => String(value ?? "").trim();
const asInt = (value) => {
    const parsed = Number(value ?? 0);
    if (!Number.isFinite(parsed))
        return 0;
    return Math.trunc(parsed);
};
const clampInt = (value, min, max) => {
    if (value < min)
        return min;
    if (value > max)
        return max;
    return value;
};
const actorRoleFromToken = (request) => {
    const tokenRole = request.auth?.token?.role;
    return asString(tokenRole).toLowerCase();
};
const resolveActorRole = async (request, uid) => {
    const tokenRole = actorRoleFromToken(request);
    if (tokenRole === "owner" || tokenRole === "tenant") {
        return tokenRole;
    }
    const userDoc = await firebase_1.db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
        return "";
    }
    return asString(userDoc.data()?.role).toLowerCase();
};
const assertActorRoleOrThrow = async (request, uid, expectedRole) => {
    const role = await resolveActorRole(request, uid);
    if (role !== expectedRole) {
        throw new https_1.HttpsError("permission-denied", "unauthorized-role");
    }
};
const requireAuthUid = (request) => {
    try {
        return (0, criticalGuards_1.resolveAuthUid)(request.auth?.uid);
    }
    catch {
        throw new https_1.HttpsError("unauthenticated", "unauthenticated");
    }
};
const assertAmountOrThrow = (amount) => {
    if (!(0, criticalGuards_1.isPaymentAmountValid)(amount, MIN_PAYMENT_AMOUNT, MAX_PAYMENT_AMOUNT)) {
        throw new https_1.HttpsError("invalid-argument", "invalid-amount");
    }
};
const buildPaymentQuote = (amountInRupees) => {
    assertAmountOrThrow(amountInRupees);
    const rentAmountInPaise = amountInRupees * 100;
    const estimatedGatewayCostInPaise = Math.round(rentAmountInPaise * (GATEWAY_PERCENT / 100));
    const convenienceFeeInPaise = estimatedGatewayCostInPaise + Math.round(estimatedGatewayCostInPaise * (GST_PERCENT / 100));
    const totalPayableInPaise = rentAmountInPaise + convenienceFeeInPaise;
    return {
        rentAmountInPaise,
        convenienceFeeInPaise,
        totalPayableInPaise,
        estimatedGatewayCostInPaise,
        gatewayPercent: GATEWAY_PERCENT,
        gstPercent: GST_PERCENT,
    };
};
const hashValue = (value) => (0, node_crypto_1.createHash)("sha256").update(value).digest("hex");
const getRazorpayCredentialsOrThrow = () => {
    const keyId = asString(process.env.RAZORPAY_KEY_ID);
    const keySecret = asString(process.env.RAZORPAY_KEY_SECRET);
    if (!keyId || !keySecret) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-secret-missing");
    }
    return { keyId, keySecret };
};
const getFirstHopIp = (request) => {
    const forwardedFor = request.rawRequest.headers["x-forwarded-for"];
    if (typeof forwardedFor === "string" && forwardedFor.trim()) {
        const firstHop = forwardedFor.split(",")[0]?.trim();
        if (firstHop)
            return firstHop;
    }
    const fallbackIp = asString(request.rawRequest.ip);
    return fallbackIp || "unknown";
};
const logPaymentEvent = async (eventType, payload) => {
    try {
        await firebase_1.db.collection("_paymentEvents").add({
            eventType,
            ...payload,
            createdAt: firebase_1.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        (0, logger_1.logWarn)("Payment event logging failed", {
            eventType,
            error: error instanceof Error ? error.message : String(error),
        });
    }
};
const enforceAbuseLimit = async (request, uid, action) => {
    const appId = asString(request.app?.appId || "unknown");
    const firstHopIpHash = hashValue(getFirstHopIp(request)).slice(0, 32);
    const minuteKey = new Date().toISOString().slice(0, 16);
    const limits = ABUSE_LIMITS[action];
    const buckets = [
        { key: `user:${uid}`, limit: limits.user },
        { key: `app:${appId}`, limit: limits.app },
        { key: `ip:${firstHopIpHash}`, limit: limits.ip },
    ];
    for (const bucket of buckets) {
        const bucketId = `${action}|${bucket.key}|${minuteKey}`;
        const ref = firebase_1.db.collection("_requestRateLimits").doc(bucketId);
        const blocked = await firebase_1.db.runTransaction(async (tx) => {
            const snap = await tx.get(ref);
            const count = snap.exists ? asInt(snap.get("count")) : 0;
            if (count >= bucket.limit) {
                return true;
            }
            tx.set(ref, {
                action,
                bucket: bucket.key,
                minuteKey,
                count: count + 1,
                limit: bucket.limit,
                updatedAt: firebase_1.FieldValue.serverTimestamp(),
                createdAt: snap.exists ? snap.get("createdAt") ?? firebase_1.FieldValue.serverTimestamp() : firebase_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            return false;
        });
        if (blocked) {
            await firebase_1.db.collection("_requestAbuseAudit").add({
                action,
                uid,
                appId,
                ipBucketHash: firstHopIpHash,
                blockedBucket: bucket.key,
                minuteKey,
                createdAt: firebase_1.FieldValue.serverTimestamp(),
            });
            throw new https_1.HttpsError("resource-exhausted", "rate-limited");
        }
    }
};
const assertAccessAndOwnership = async (uid, tenantId, propertyId) => {
    const [tenantDoc, propertyDoc] = await Promise.all([
        firebase_1.db.collection("tenants").doc(tenantId).get(),
        firebase_1.db.collection("properties").doc(propertyId).get(),
    ]);
    if (!tenantDoc.exists) {
        throw new https_1.HttpsError("not-found", "invalid-tenant");
    }
    if (!propertyDoc.exists) {
        throw new https_1.HttpsError("not-found", "invalid-property");
    }
    const tenantData = tenantDoc.data() ?? {};
    const propertyData = propertyDoc.data() ?? {};
    const ownerId = asString(tenantData.ownerId);
    const tenantPropertyId = asString(tenantData.propertyId);
    const propertyOwnerId = asString(propertyData.ownerId);
    if (!ownerId || tenantPropertyId !== propertyId || propertyOwnerId !== ownerId) {
        throw new https_1.HttpsError("failed-precondition", "invalid-owner");
    }
    const isOwnerActor = uid === ownerId;
    const isTenantActor = uid === tenantId;
    if (!isOwnerActor && !isTenantActor) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    return { ownerId };
};
const resolveRentPaymentParticipants = async (uid, data) => {
    const tenantId = asString(data.tenantId);
    const propertyId = asString(data.propertyId);
    if (tenantId && propertyId) {
        const { ownerId } = await assertAccessAndOwnership(uid, tenantId, propertyId);
        return { ownerId, tenantId, propertyId };
    }
    const actorTenantDoc = await firebase_1.db.collection("tenants").doc(uid).get();
    if (!actorTenantDoc.exists) {
        throw new https_1.HttpsError("invalid-argument", "missing-tenant-property");
    }
    const tenant = actorTenantDoc.data() ?? {};
    const resolvedTenantId = asString(tenant.tenantId || actorTenantDoc.id);
    const resolvedOwnerId = asString(tenant.ownerId);
    const resolvedPropertyId = asString(tenant.propertyId);
    if (!resolvedTenantId || !resolvedOwnerId || !resolvedPropertyId) {
        throw new https_1.HttpsError("failed-precondition", "invalid-tenant-linkage");
    }
    if (resolvedTenantId !== uid) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    await assertAccessAndOwnership(uid, resolvedTenantId, resolvedPropertyId);
    return {
        ownerId: resolvedOwnerId,
        tenantId: resolvedTenantId,
        propertyId: resolvedPropertyId,
    };
};
const resolveBillingCycleOrThrow = (data) => {
    const now = new Date();
    const requestedMonth = asInt(data.month);
    const requestedYear = asInt(data.year);
    const month = requestedMonth > 0 ? requestedMonth : now.getMonth() + 1;
    const year = requestedYear > 0 ? requestedYear : now.getFullYear();
    if (month < 1 || month > 12) {
        throw new https_1.HttpsError("invalid-argument", "invalid-billing-month");
    }
    if (year < 2020 || year > 2100) {
        throw new https_1.HttpsError("invalid-argument", "invalid-billing-year");
    }
    return {
        month,
        year,
        paymentMonth: `${year}-${String(month).padStart(2, "0")}`,
    };
};
const resolveCycleDueDate = (year, month, preferredDay) => {
    const safeDay = clampInt(preferredDay, 1, 31);
    const maxDay = new Date(year, month, 0).getDate();
    return new Date(Date.UTC(year, month - 1, Math.min(safeDay, maxDay), 0, 0, 0, 0));
};
const resolveAuthoritativeRentCharge = async (uid, data) => {
    const participants = await resolveRentPaymentParticipants(uid, data);
    const cycle = resolveBillingCycleOrThrow(data);
    const requestedLeaseId = asString(data.leaseId);
    const [tenantDoc, leaseDoc] = await Promise.all([
        firebase_1.db.collection("tenants").doc(participants.tenantId).get(),
        requestedLeaseId ? firebase_1.db.collection("leases").doc(requestedLeaseId).get() : Promise.resolve(null),
    ]);
    if (!tenantDoc.exists) {
        throw new https_1.HttpsError("failed-precondition", "invalid-tenant-linkage");
    }
    const tenantData = tenantDoc.data() ?? {};
    const tenantOwnerId = asString(tenantData.ownerId);
    const tenantPropertyId = asString(tenantData.propertyId);
    if (tenantOwnerId !== participants.ownerId || tenantPropertyId !== participants.propertyId) {
        throw new https_1.HttpsError("failed-precondition", "invalid-tenant-linkage");
    }
    const leaseData = leaseDoc?.exists ? leaseDoc.data() ?? {} : null;
    if (leaseDoc?.exists) {
        const leaseOwnerId = asString(leaseData?.ownerId);
        const leaseTenantId = asString(leaseData?.tenantId);
        const leasePropertyId = asString(leaseData?.propertyId);
        if (leaseOwnerId !== participants.ownerId ||
            leaseTenantId !== participants.tenantId ||
            leasePropertyId !== participants.propertyId) {
            throw new https_1.HttpsError("failed-precondition", "invalid-lease-linkage");
        }
    }
    const leaseStatus = asString(leaseData?.status).toLowerCase();
    if (leaseStatus && leaseStatus !== "active") {
        throw new https_1.HttpsError("failed-precondition", "inactive-lease");
    }
    const rentAmountInRupees = asInt(leaseData?.rentAmount ?? leaseData?.monthlyRent ?? tenantData.rentAmount ?? tenantData.monthlyRent);
    assertAmountOrThrow(rentAmountInRupees);
    const dueAmountInRupees = asInt(tenantData.dueAmount);
    const outstandingComponent = dueAmountInRupees > 0 ? dueAmountInRupees : 0;
    const baseAmountInRupees = Math.max(rentAmountInRupees, outstandingComponent);
    assertAmountOrThrow(baseAmountInRupees);
    const dueDay = asInt(leaseData?.rentDueDay ?? tenantData.rentDueDate ?? 1);
    const dueDate = resolveCycleDueDate(cycle.year, cycle.month, dueDay);
    const isOverdue = Date.now() > dueDate.getTime();
    const configuredLateFee = asInt(leaseData?.lateFeeAmount ?? tenantData.lateFeeAmount);
    const lateFeePercentage = asInt(leaseData?.lateFeePercentage ?? tenantData.lateFeePercentage);
    let lateFeeAmountInRupees = 0;
    if (configuredLateFee > 0 && isOverdue) {
        lateFeeAmountInRupees = configuredLateFee;
    }
    else if (lateFeePercentage > 0 && isOverdue) {
        lateFeeAmountInRupees = Math.round(baseAmountInRupees * (lateFeePercentage / 100));
    }
    const totalChargeInRupees = baseAmountInRupees + Math.max(0, lateFeeAmountInRupees);
    assertAmountOrThrow(totalChargeInRupees);
    const clientRequestedAmount = asInt(data.enteredRentAmountInRupees ?? data.amount);
    if (clientRequestedAmount > 0 && clientRequestedAmount !== totalChargeInRupees) {
        throw new https_1.HttpsError("failed-precondition", "amount-mismatch-server-authoritative");
    }
    const quote = buildPaymentQuote(totalChargeInRupees);
    const resolvedLeaseId = asString(leaseData?.id || leaseDoc?.id || data.leaseId);
    return {
        ...participants,
        leaseId: resolvedLeaseId,
        month: cycle.month,
        year: cycle.year,
        paymentMonth: cycle.paymentMonth,
        dueDateIso: dueDate.toISOString(),
        isOverdue,
        baseAmountInRupees,
        lateFeeAmountInRupees: Math.max(0, lateFeeAmountInRupees),
        totalChargeInRupees,
        quote,
    };
};
const createRazorpayOrder = async (amountInPaise, currency, receipt) => {
    const { keyId, keySecret } = getRazorpayCredentialsOrThrow();
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
    const response = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
            Authorization: `Basic ${auth}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            amount: amountInPaise,
            currency,
            receipt,
            payment_capture: 1,
        }),
    });
    if (!response.ok) {
        const body = await response.text();
        (0, logger_1.logError)("Razorpay order create failed", { body, amountInPaise, currency, receipt });
        throw new https_1.HttpsError("internal", "razorpay-order-create-failed");
    }
    const payload = (await response.json());
    const orderId = asString(payload.id);
    if (!orderId) {
        throw new https_1.HttpsError("internal", "razorpay-order-create-invalid-response");
    }
    return { orderId, keyId };
};
const createRentPaymentIntentInternal = async (uid, data) => {
    const rentCharge = await resolveAuthoritativeRentCharge(uid, data);
    const idempotencyKey = asString(data.idempotencyKey || (0, node_crypto_1.randomUUID)());
    const quote = rentCharge.quote;
    const existing = await firebase_1.db
        .collection(PAYMENT_COLLECTION)
        .where("actorUid", "==", uid)
        .where("ownerId", "==", rentCharge.ownerId)
        .where("tenantId", "==", rentCharge.tenantId)
        .where("idempotencyKey", "==", idempotencyKey)
        .limit(1)
        .get();
    if (!existing.empty) {
        const existingDoc = existing.docs[0];
        const existingData = existingDoc.data();
        return {
            paymentId: existingDoc.id,
            orderId: asString(existingData.razorpayOrderId),
            keyId: asString(process.env.RAZORPAY_KEY_ID),
            amountInPaise: asInt(existingData.amountInPaise),
            rentAmountInPaise: asInt(existingData.rentAmountInPaise),
            convenienceFeeInPaise: asInt(existingData.convenienceFeeInPaise),
            totalPayableInPaise: asInt(existingData.totalPayableInPaise),
            estimatedGatewayCostInPaise: asInt(existingData.estimatedGatewayCostInPaise),
            gatewayPercent: GATEWAY_PERCENT,
            gstPercent: GST_PERCENT,
            currency: asString(existingData.currency || DEFAULT_CURRENCY),
            leaseId: asString(existingData.leaseId),
            month: asInt(existingData.month),
            year: asInt(existingData.year),
            paymentMonth: asString(existingData.paymentMonth),
            baseAmountInRupees: asInt(existingData.baseAmountInRupees ?? existingData.amount),
            lateFeeAmountInRupees: asInt(existingData.lateFeeAmountInRupees),
            isOverdue: existingData.isOverdue === true,
            dueDateIso: asString(existingData.dueDateIso),
            idempotencyKey,
            gateway: "razorpay",
            idempotent: true,
            status: asString(existingData.status || "pending"),
        };
    }
    const receipt = `rent_${rentCharge.tenantId}_${Date.now()}`;
    const order = await createRazorpayOrder(quote.totalPayableInPaise, DEFAULT_CURRENCY, receipt);
    const paymentRef = firebase_1.db.collection(PAYMENT_COLLECTION).doc();
    const now = firebase_1.FieldValue.serverTimestamp();
    await paymentRef.set({
        id: paymentRef.id,
        actorUid: uid,
        ownerId: rentCharge.ownerId,
        tenantId: rentCharge.tenantId,
        propertyId: rentCharge.propertyId,
        leaseId: rentCharge.leaseId,
        month: rentCharge.month,
        year: rentCharge.year,
        paymentMonth: rentCharge.paymentMonth,
        dueDateIso: rentCharge.dueDateIso,
        isOverdue: rentCharge.isOverdue,
        baseAmountInRupees: rentCharge.baseAmountInRupees,
        lateFeeAmountInRupees: rentCharge.lateFeeAmountInRupees,
        amount: rentCharge.totalChargeInRupees,
        currency: DEFAULT_CURRENCY,
        amountInPaise: quote.totalPayableInPaise,
        rentAmountInPaise: quote.rentAmountInPaise,
        convenienceFeeInPaise: quote.convenienceFeeInPaise,
        estimatedGatewayCostInPaise: quote.estimatedGatewayCostInPaise,
        totalPayableInPaise: quote.totalPayableInPaise,
        paidAmount: 0,
        remainingAmount: rentCharge.totalChargeInRupees,
        method: "razorpay",
        status: "pending",
        remoteStatus: "created",
        idempotencyKey,
        razorpayOrderId: order.orderId,
        razorpayPaymentId: null,
        razorpaySignatureHash: null,
        verifiedBy: null,
        verifiedAt: null,
        createdAt: now,
        updatedAt: now,
    });
    await logPaymentEvent("PAYMENT_INTENT_CREATED", {
        paymentId: paymentRef.id,
        ownerId: rentCharge.ownerId,
        tenantId: rentCharge.tenantId,
        propertyId: rentCharge.propertyId,
        leaseId: rentCharge.leaseId,
        paymentMonth: rentCharge.paymentMonth,
        actorUid: uid,
        idempotencyKey,
        amountInPaise: quote.totalPayableInPaise,
    });
    return {
        paymentId: paymentRef.id,
        orderId: order.orderId,
        keyId: order.keyId,
        amountInPaise: quote.totalPayableInPaise,
        rentAmountInPaise: quote.rentAmountInPaise,
        convenienceFeeInPaise: quote.convenienceFeeInPaise,
        totalPayableInPaise: quote.totalPayableInPaise,
        estimatedGatewayCostInPaise: quote.estimatedGatewayCostInPaise,
        gatewayPercent: GATEWAY_PERCENT,
        gstPercent: GST_PERCENT,
        currency: DEFAULT_CURRENCY,
        leaseId: rentCharge.leaseId,
        month: rentCharge.month,
        year: rentCharge.year,
        paymentMonth: rentCharge.paymentMonth,
        baseAmountInRupees: rentCharge.baseAmountInRupees,
        lateFeeAmountInRupees: rentCharge.lateFeeAmountInRupees,
        isOverdue: rentCharge.isOverdue,
        dueDateIso: rentCharge.dueDateIso,
        idempotencyKey,
        gateway: "razorpay",
        idempotent: false,
        status: "pending",
    };
};
const verifyRentPaymentInternal = async (uid, data) => {
    const paymentId = asString(data.paymentId);
    const payload = (data.payload ?? {});
    const razorpayOrderId = asString(data.razorpayOrderId ?? payload.orderId);
    const razorpayPaymentId = asString(data.razorpayPaymentId ?? payload.paymentId);
    const razorpaySignature = asString(data.razorpaySignature ?? payload.signature);
    if (!paymentId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        throw new https_1.HttpsError("invalid-argument", "invalid-verification-payload");
    }
    const paymentDoc = await firebase_1.db.collection(PAYMENT_COLLECTION).doc(paymentId).get();
    if (!paymentDoc.exists) {
        throw new https_1.HttpsError("not-found", "payment-not-found");
    }
    const payment = paymentDoc.data() ?? {};
    const ownerId = asString(payment.ownerId);
    const tenantId = asString(payment.tenantId);
    if (uid !== ownerId && uid !== tenantId) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    if (asString(payment.status).toLowerCase() == "paid") {
        throw new https_1.HttpsError("already-exists", "already-verified");
    }
    try {
        const result = await (0, paymentService_1.verifyRazorpayPayment)({
            paymentId,
            razorpayOrderId,
            razorpayPaymentId,
            razorpaySignature,
            actorUid: uid,
        });
        return {
            paymentId: result.paymentId,
            status: result.status,
            paidAmount: result.paidAmount,
            remainingAmount: result.remainingAmount,
            amountInPaise: result.amountInPaise,
            currency: result.currency,
        };
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        if (msg === "payment-not-found")
            throw new https_1.HttpsError("not-found", "payment-not-found");
        if (msg === "unauthorized")
            throw new https_1.HttpsError("permission-denied", "unauthorized");
        if (msg === "order-mismatch")
            throw new https_1.HttpsError("failed-precondition", "order-mismatch");
        if (msg === "invalid-signature")
            throw new https_1.HttpsError("permission-denied", "invalid-signature");
        if (msg.startsWith("payment-not-captured"))
            throw new https_1.HttpsError("failed-precondition", msg);
        if (msg.startsWith("razorpay-") || msg.startsWith("razorpay-fetch-failed")) {
            throw new https_1.HttpsError("failed-precondition", msg);
        }
        throw new https_1.HttpsError("internal", "internal-error");
    }
};
const verifyStoredRazorpayPayment = async (params) => {
    const { expectedOrderId, expectedAmountInPaise, expectedCurrency, razorpayOrderId, razorpayPaymentId, razorpaySignature, } = params;
    if (expectedOrderId !== razorpayOrderId) {
        throw new https_1.HttpsError("failed-precondition", "order-mismatch");
    }
    const { keyId, keySecret } = getRazorpayCredentialsOrThrow();
    const expectedSignature = (0, node_crypto_1.createHmac)("sha256", keySecret)
        .update(`${razorpayOrderId}|${razorpayPaymentId}`)
        .digest("hex");
    const expected = Buffer.from(expectedSignature);
    const provided = Buffer.from(razorpaySignature);
    if (expected.length !== provided.length || !(0, node_crypto_1.timingSafeEqual)(expected, provided)) {
        throw new https_1.HttpsError("permission-denied", "invalid-signature");
    }
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
    const response = await fetch(`https://api.razorpay.com/v1/payments/${encodeURIComponent(razorpayPaymentId)}`, {
        method: "GET",
        headers: {
            Authorization: `Basic ${auth}`,
            "Content-Type": "application/json",
        },
    });
    if (!response.ok) {
        const body = await response.text();
        throw new https_1.HttpsError("internal", `razorpay-fetch-failed:${body}`);
    }
    const remote = (await response.json());
    const remoteOrderId = asString(remote.order_id);
    const remoteAmount = asInt(remote.amount);
    const remoteCurrency = asString(remote.currency).toUpperCase();
    const remoteStatus = asString(remote.status).toLowerCase();
    if (remoteOrderId !== razorpayOrderId) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-order-validation-failed");
    }
    if (remoteAmount !== expectedAmountInPaise) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-amount-validation-failed");
    }
    if (remoteCurrency !== expectedCurrency.toUpperCase()) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-currency-validation-failed");
    }
    if (remoteStatus !== "captured") {
        throw new https_1.HttpsError("failed-precondition", `payment-not-captured:${remoteStatus}`);
    }
    const signatureHash = (0, node_crypto_1.createHmac)("sha256", keySecret)
        .update(razorpaySignature)
        .digest("hex");
    return { signatureHash, remoteStatus };
};
const getRazorpayWebhookSecretOrThrow = () => {
    const secret = asString(process.env.RAZORPAY_WEBHOOK_SECRET);
    if (!secret) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-webhook-secret-missing");
    }
    return secret;
};
const readRawWebhookBodyOrThrow = (request) => {
    if (Buffer.isBuffer(request.rawBody)) {
        if (request.rawBody.byteLength > MAX_WEBHOOK_RAW_BODY_BYTES) {
            throw new https_1.HttpsError("invalid-argument", "webhook-payload-too-large");
        }
        return request.rawBody.toString("utf8");
    }
    const fallback = JSON.stringify(request.body ?? {});
    if (Buffer.byteLength(fallback, "utf8") > MAX_WEBHOOK_RAW_BODY_BYTES) {
        throw new https_1.HttpsError("invalid-argument", "webhook-payload-too-large");
    }
    return fallback;
};
const verifyWebhookSignatureOrThrow = (signatureHeader, rawBody, secret) => {
    const expectedSignature = (0, node_crypto_1.createHmac)("sha256", secret).update(rawBody).digest("hex");
    const expected = Buffer.from(expectedSignature);
    const provided = Buffer.from(signatureHeader);
    if (expected.length !== provided.length || !(0, node_crypto_1.timingSafeEqual)(expected, provided)) {
        throw new https_1.HttpsError("permission-denied", "invalid-webhook-signature");
    }
};
const finalizeWebhookPaymentCapture = async (params) => {
    const { paymentId, razorpayOrderId, razorpayPaymentId, amountInPaise, currency, eventId } = params;
    const paymentRef = firebase_1.db.collection(PAYMENT_COLLECTION).doc(paymentId);
    await firebase_1.db.runTransaction(async (tx) => {
        const paymentSnap = await tx.get(paymentRef);
        if (!paymentSnap.exists) {
            throw new https_1.HttpsError("not-found", "payment-not-found");
        }
        const paymentData = paymentSnap.data() ?? {};
        const storedOrderId = asString(paymentData.razorpayOrderId);
        const storedStatus = asString(paymentData.status).toLowerCase();
        const expectedAmountInPaise = asInt(paymentData.amountInPaise);
        const expectedCurrency = asString(paymentData.currency || DEFAULT_CURRENCY).toUpperCase();
        if (!storedOrderId || storedOrderId !== razorpayOrderId) {
            throw new https_1.HttpsError("failed-precondition", "order-mismatch");
        }
        if (amountInPaise !== expectedAmountInPaise) {
            throw new https_1.HttpsError("failed-precondition", "razorpay-amount-validation-failed");
        }
        if (currency.toUpperCase() !== expectedCurrency) {
            throw new https_1.HttpsError("failed-precondition", "razorpay-currency-validation-failed");
        }
        if (storedStatus === "paid") {
            return;
        }
        const paidAt = firebase_1.Timestamp.now();
        const paidDate = paidAt.toDate();
        const receiptNumber = `RCP-${paidDate.getFullYear()}${String(paidDate.getMonth() + 1).padStart(2, "0")}-${paymentId.slice(-6).toUpperCase()}`;
        tx.set(paymentRef, {
            status: "paid",
            method: "razorpay",
            remoteStatus: "captured",
            paidAmount: Math.trunc(amountInPaise / 100),
            remainingAmount: 0,
            transactionId: razorpayPaymentId,
            razorpayPaymentId,
            verifiedBy: "razorpay_webhook",
            verifiedAt: firebase_1.FieldValue.serverTimestamp(),
            paymentDate: paidAt,
            paidAt,
            completedAt: paidAt,
            month: asInt(paymentData.month) || (paidDate.getMonth() + 1),
            year: asInt(paymentData.year) || paidDate.getFullYear(),
            receiptNumber,
            updatedAt: paidAt,
        }, { merge: true });
        const webhookEventRef = firebase_1.db.collection("_webhookEvents").doc(eventId);
        tx.set(webhookEventRef, {
            eventId,
            eventType: "payment.captured",
            paymentId,
            razorpayOrderId,
            razorpayPaymentId,
            processedAt: firebase_1.FieldValue.serverTimestamp(),
            status: "processed",
        }, { merge: true });
    });
};
exports.razorpayPaymentWebhook = (0, https_1.onRequest)({
    region: REGION,
    secrets: ["RAZORPAY_WEBHOOK_SECRET"],
}, async (request, response) => {
    if (request.method !== "POST") {
        response.status(405).json({ ok: false, code: "method-not-allowed" });
        return;
    }
    try {
        const signature = asString(request.headers["x-razorpay-signature"]);
        if (!signature) {
            response.status(401).json({ ok: false, code: "missing-webhook-signature" });
            return;
        }
        const rawBody = readRawWebhookBodyOrThrow(request);
        const webhookSecret = getRazorpayWebhookSecretOrThrow();
        verifyWebhookSignatureOrThrow(signature, rawBody, webhookSecret);
        const eventPayload = (request.body ?? {});
        const eventType = asString(eventPayload.event);
        const payloadRoot = (eventPayload.payload ?? {});
        const paymentEnvelope = (payloadRoot.payment ?? {});
        const paymentEntity = (paymentEnvelope.entity ?? {});
        const eventId = asString(eventPayload.event_id || paymentEntity.id || hashValue(rawBody));
        if (!eventId) {
            response.status(400).json({ ok: false, code: "missing-event-id" });
            return;
        }
        const webhookEventRef = firebase_1.db.collection("_webhookEvents").doc(eventId);
        const priorEvent = await webhookEventRef.get();
        if (priorEvent.exists && asString(priorEvent.data()?.status) === "processed") {
            response.status(200).json({ ok: true, duplicate: true });
            return;
        }
        if (eventType !== "payment.captured") {
            await webhookEventRef.set({
                eventId,
                eventType,
                status: "ignored",
                receivedAt: firebase_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            response.status(200).json({ ok: true, ignored: true });
            return;
        }
        const razorpayPaymentId = asString(paymentEntity.id);
        const razorpayOrderId = asString(paymentEntity.order_id);
        const currency = asString(paymentEntity.currency || DEFAULT_CURRENCY).toUpperCase();
        const amountInPaise = asInt(paymentEntity.amount);
        const remoteStatus = asString(paymentEntity.status).toLowerCase();
        if (!razorpayPaymentId || !razorpayOrderId || amountInPaise <= 0) {
            response.status(400).json({ ok: false, code: "invalid-webhook-payload" });
            return;
        }
        if (remoteStatus && remoteStatus !== "captured") {
            response.status(202).json({ ok: true, ignored: true, reason: "not-captured" });
            return;
        }
        const paymentMatch = await firebase_1.db
            .collection(PAYMENT_COLLECTION)
            .where("razorpayOrderId", "==", razorpayOrderId)
            .limit(1)
            .get();
        if (paymentMatch.empty) {
            await webhookEventRef.set({
                eventId,
                eventType,
                status: "unmatched",
                razorpayOrderId,
                razorpayPaymentId,
                receivedAt: firebase_1.FieldValue.serverTimestamp(),
            }, { merge: true });
            response.status(202).json({ ok: true, unmatched: true });
            return;
        }
        const paymentId = paymentMatch.docs[0].id;
        await finalizeWebhookPaymentCapture({
            paymentId,
            razorpayOrderId,
            razorpayPaymentId,
            amountInPaise,
            currency,
            eventId,
        });
        await logPaymentEvent("PAYMENT_WEBHOOK_CAPTURED", {
            eventId,
            paymentId,
            razorpayOrderId,
            razorpayPaymentId,
            amountInPaise,
        });
        response.status(200).json({ ok: true, paymentId, processed: true });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        (0, logger_1.logError)("Razorpay webhook failed", { message });
        response.status(400).json({ ok: false, code: "webhook-processing-failed" });
    }
});
const resolveOwnerPlanOrThrow = (planCodeRaw) => {
    const planCode = asString(planCodeRaw).toLowerCase();
    const plan = OWNER_SUBSCRIPTION_PLANS[planCode];
    if (!plan) {
        throw new https_1.HttpsError("invalid-argument", "invalid-plan-code");
    }
    return plan;
};
const resolveTenantPlanOrThrow = (planCodeRaw) => {
    const planCode = asString(planCodeRaw).toLowerCase();
    const plan = TENANT_SUBSCRIPTION_PLANS[planCode];
    if (!plan) {
        throw new https_1.HttpsError("invalid-argument", "invalid-plan-code");
    }
    return plan;
};
exports.quoteOwnerRazorpayPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    requireAuthUid(request);
    const amount = asInt(request.data?.amount);
    const quote = buildPaymentQuote(amount);
    return {
        ...quote,
        currency: DEFAULT_CURRENCY,
    };
});
exports.quotePayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = requireAuthUid(request);
    const authoritativeCharge = await resolveAuthoritativeRentCharge(uid, (request.data ?? {}));
    const gateway = asString(request.data?.gateway || "razorpay") || "razorpay";
    return {
        leaseId: authoritativeCharge.leaseId,
        gateway,
        month: authoritativeCharge.month,
        year: authoritativeCharge.year,
        paymentMonth: authoritativeCharge.paymentMonth,
        dueDateIso: authoritativeCharge.dueDateIso,
        baseAmountInRupees: authoritativeCharge.baseAmountInRupees,
        lateFeeAmountInRupees: authoritativeCharge.lateFeeAmountInRupees,
        ...authoritativeCharge.quote,
        currency: DEFAULT_CURRENCY,
        isOverdue: authoritativeCharge.isOverdue,
    };
});
exports.createOwnerRazorpayPaymentIntent = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "owner");
    await enforceAbuseLimit(request, uid, "payment_create");
    return createRentPaymentIntentInternal(uid, request.data);
});
exports.createPaymentIntent = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await enforceAbuseLimit(request, uid, "payment_create");
    return createRentPaymentIntentInternal(uid, request.data);
});
exports.createPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await enforceAbuseLimit(request, uid, "payment_create");
    const intent = await createRentPaymentIntentInternal(uid, request.data);
    return {
        paymentId: asString(intent.paymentId),
        status: asString(intent.status || "pending"),
        idempotent: intent.idempotent === true,
        orderId: asString(intent.orderId),
        keyId: asString(intent.keyId),
        amountInPaise: asInt(intent.amountInPaise),
        currency: asString(intent.currency || DEFAULT_CURRENCY),
    };
});
exports.verifyOwnerRazorpayPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "owner");
    await enforceAbuseLimit(request, uid, "payment_verify");
    return verifyRentPaymentInternal(uid, request.data);
});
exports.verifyPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await enforceAbuseLimit(request, uid, "payment_verify");
    return verifyRentPaymentInternal(uid, request.data);
});
exports.confirmRazorpayPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await enforceAbuseLimit(request, uid, "payment_verify");
    return verifyRentPaymentInternal(uid, request.data);
});
exports.updatePaymentStatus = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = requireAuthUid(request);
    const paymentId = asString(request.data?.paymentId);
    const requestedStatus = asString(request.data?.newStatus).toLowerCase();
    const installmentAmount = asInt(request.data?.installmentAmount);
    const installmentMethod = asString(request.data?.installmentMethod || "manual").toLowerCase();
    const installmentNotes = asString(request.data?.installmentNotes);
    if (!paymentId || !["paid", "partial", "unpaid"].includes(requestedStatus)) {
        throw new https_1.HttpsError("invalid-argument", "invalid-status");
    }
    const paymentRef = firebase_1.db.collection(PAYMENT_COLLECTION).doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
        throw new https_1.HttpsError("not-found", "payment-not-found");
    }
    const data = paymentDoc.data() ?? {};
    const ownerId = asString(data.ownerId);
    const method = asString(data.method).toLowerCase();
    if (uid !== ownerId) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    // Razorpay-backed payment lifecycle is server-owned and must not be
    // manually finalized or reverted through legacy status updates.
    if (method === "razorpay") {
        throw new https_1.HttpsError("failed-precondition", "status-managed-by-backend");
    }
    const baseAmount = asInt(data.baseAmount ?? data.amount);
    let paidAmount = asInt(data.paidAmount);
    const installmentsRaw = Array.isArray(data.installments) ? data.installments : [];
    const installments = [...installmentsRaw];
    if (requestedStatus === "partial") {
        if (installmentAmount <= 0) {
            throw new https_1.HttpsError("invalid-argument", "invalid-amount");
        }
        const remainingBefore = Math.max(0, baseAmount - paidAmount);
        if (installmentAmount > remainingBefore) {
            throw new https_1.HttpsError("failed-precondition", "invalid-installment");
        }
        paidAmount += installmentAmount;
        installments.push({
            amount: installmentAmount,
            date: firebase_1.FieldValue.serverTimestamp(),
            method: installmentMethod || "manual",
            notes: installmentNotes || null,
        });
    }
    else if (requestedStatus === "paid") {
        paidAmount = baseAmount;
        installments.push({
            amount: Math.max(0, baseAmount - asInt(data.paidAmount)),
            date: firebase_1.FieldValue.serverTimestamp(),
            method: installmentMethod || "manual",
            notes: installmentNotes || "status updated to paid",
        });
    }
    else {
        paidAmount = 0;
        installments.length = 0;
    }
    const safePaid = Math.max(0, Math.min(baseAmount, paidAmount));
    const remainingAmount = Math.max(0, baseAmount - safePaid);
    const resolvedStatus = remainingAmount === 0 ? "paid" : safePaid > 0 ? "partial" : "pending";
    await paymentRef.update({
        paidAmount: safePaid,
        remainingAmount,
        status: resolvedStatus,
        installments,
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    });
    return {
        paymentId,
        status: resolvedStatus,
        paidAmount: safePaid,
        remainingAmount,
    };
});
exports.ensureOwnerSubscriptionProfile = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "owner");
    const ownerId = asString(request.data?.ownerId || uid);
    const email = asString(request.data?.email || request.auth?.token.email || "");
    if (ownerId !== uid) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    const ownerRef = firebase_1.db.collection("owners").doc(ownerId);
    await ownerRef.set({
        ownerId,
        email,
        subscriptionPlan: "free",
        paymentStatus: "active",
        tenantLimit: 2,
        currentTenantCount: 0,
        subscriptionStartDate: firebase_1.FieldValue.serverTimestamp(),
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ownerId, ensured: true };
});
exports.getOwnerSubscriptionSnapshot = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "owner");
    const ownerId = asString(request.data?.ownerId || uid);
    if (ownerId !== uid) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    const ownerDoc = await firebase_1.db.collection("owners").doc(ownerId).get();
    if (!ownerDoc.exists) {
        await firebase_1.db.collection("owners").doc(ownerId).set({
            ownerId,
            email: asString(request.data?.email || request.auth?.token.email || ""),
            subscriptionPlan: "free",
            paymentStatus: "active",
            tenantLimit: 2,
            currentTenantCount: 0,
            subscriptionStartDate: firebase_1.FieldValue.serverTimestamp(),
            updatedAt: firebase_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    const refreshed = await firebase_1.db.collection("owners").doc(ownerId).get();
    return { ownerId, ...(refreshed.data() ?? {}) };
});
exports.activateOwnerFreeSubscription = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "owner");
    const ownerId = asString(request.data?.ownerId || uid);
    if (ownerId !== uid) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    await firebase_1.db.collection("owners").doc(ownerId).set({
        ownerId,
        subscriptionPlan: "free",
        paymentStatus: "active",
        tenantLimit: 2,
        subscriptionStartDate: firebase_1.FieldValue.serverTimestamp(),
        subscriptionExpiry: null,
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ownerId, planCode: "free", active: true };
});
exports.createOwnerSubscriptionPaymentIntent = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "owner");
    await enforceAbuseLimit(request, uid, "owner_subscription_create");
    const plan = resolveOwnerPlanOrThrow(request.data?.planCode);
    const idempotencyKey = asString(request.data?.idempotencyKey || (0, node_crypto_1.randomUUID)());
    const existing = await firebase_1.db
        .collection(OWNER_SUBSCRIPTION_COLLECTION)
        .where("actorUid", "==", uid)
        .where("ownerId", "==", uid)
        .where("planCode", "==", plan.code)
        .where("idempotencyKey", "==", idempotencyKey)
        .limit(1)
        .get();
    if (!existing.empty) {
        const existingDoc = existing.docs[0];
        const data = existingDoc.data();
        return {
            subscriptionPaymentId: existingDoc.id,
            paymentId: existingDoc.id,
            orderId: asString(data.razorpayOrderId),
            keyId: asString(process.env.RAZORPAY_KEY_ID),
            amountInPaise: asInt(data.amountInPaise),
            currency: asString(data.currency || DEFAULT_CURRENCY),
            planCode: plan.code,
            tenantLimit: plan.tenantLimit,
            idempotencyKey,
        };
    }
    const amountInPaise = plan.monthlyPriceInRupees * 100;
    const order = await createRazorpayOrder(amountInPaise, DEFAULT_CURRENCY, `owner_sub_${uid}_${Date.now()}`);
    const paymentRef = firebase_1.db.collection(OWNER_SUBSCRIPTION_COLLECTION).doc();
    await paymentRef.set({
        id: paymentRef.id,
        actorUid: uid,
        ownerId: uid,
        planCode: plan.code,
        planTitle: plan.title,
        tenantLimit: plan.tenantLimit,
        amountInPaise,
        currency: DEFAULT_CURRENCY,
        status: "pending",
        remoteStatus: "created",
        idempotencyKey,
        razorpayOrderId: order.orderId,
        razorpayPaymentId: null,
        razorpaySignatureHash: null,
        verifiedBy: null,
        verifiedAt: null,
        createdAt: firebase_1.FieldValue.serverTimestamp(),
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    });
    return {
        subscriptionPaymentId: paymentRef.id,
        paymentId: paymentRef.id,
        orderId: order.orderId,
        keyId: order.keyId,
        amountInPaise,
        currency: DEFAULT_CURRENCY,
        planCode: plan.code,
        tenantLimit: plan.tenantLimit,
        idempotencyKey,
    };
});
exports.verifyOwnerSubscriptionPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "owner");
    await enforceAbuseLimit(request, uid, "owner_subscription_verify");
    const subscriptionPaymentId = asString(request.data?.subscriptionPaymentId || request.data?.paymentId);
    const payload = (request.data?.payload ?? {});
    const razorpayOrderId = asString(request.data?.razorpayOrderId ?? payload.orderId);
    const razorpayPaymentId = asString(request.data?.razorpayPaymentId ?? payload.paymentId);
    const razorpaySignature = asString(request.data?.razorpaySignature ?? payload.signature);
    if (!subscriptionPaymentId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        throw new https_1.HttpsError("invalid-argument", "invalid-verification-payload");
    }
    const paymentRef = firebase_1.db.collection(OWNER_SUBSCRIPTION_COLLECTION).doc(subscriptionPaymentId);
    const snap = await paymentRef.get();
    if (!snap.exists)
        throw new https_1.HttpsError("not-found", "payment-not-found");
    const data = snap.data() ?? {};
    const actorUid = asString(data.actorUid);
    const ownerId = asString(data.ownerId);
    if (uid !== ownerId) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    if (actorUid && actorUid !== uid) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    if (asString(data.status).toLowerCase() === "paid") {
        throw new https_1.HttpsError("already-exists", "already-verified");
    }
    const verification = await verifyStoredRazorpayPayment({
        expectedOrderId: asString(data.razorpayOrderId),
        expectedAmountInPaise: asInt(data.amountInPaise),
        expectedCurrency: asString(data.currency || DEFAULT_CURRENCY),
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature,
    });
    await paymentRef.set({
        status: "paid",
        remoteStatus: verification.remoteStatus,
        razorpayPaymentId,
        razorpaySignatureHash: verification.signatureHash,
        verifiedBy: uid,
        verifiedAt: firebase_1.FieldValue.serverTimestamp(),
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const planCode = asString(data.planCode || "basic");
    const plan = resolveOwnerPlanOrThrow(planCode);
    const startsAt = firebase_1.Timestamp.now();
    const expiry = firebase_1.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));
    await firebase_1.db.collection("owners").doc(uid).set({
        ownerId: uid,
        subscriptionPlan: plan.code,
        paymentStatus: "active",
        tenantLimit: plan.tenantLimit,
        subscriptionStartDate: startsAt,
        subscriptionExpiry: expiry,
        paymentOrderId: razorpayOrderId,
        paymentSubscriptionId: subscriptionPaymentId,
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        subscriptionPaymentId,
        ownerId: uid,
        status: "paid",
        planCode: plan.code,
        tenantLimit: plan.tenantLimit,
    };
});
exports.createTenantSubscriptionPaymentIntent = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "tenant");
    await enforceAbuseLimit(request, uid, "tenant_subscription_create");
    const plan = resolveTenantPlanOrThrow(request.data?.planCode);
    const idempotencyKey = asString(request.data?.idempotencyKey || (0, node_crypto_1.randomUUID)());
    const existing = await firebase_1.db
        .collection(TENANT_SUBSCRIPTION_COLLECTION)
        .where("actorUid", "==", uid)
        .where("tenantId", "==", uid)
        .where("planCode", "==", plan.code)
        .where("idempotencyKey", "==", idempotencyKey)
        .limit(1)
        .get();
    if (!existing.empty) {
        const existingDoc = existing.docs[0];
        const data = existingDoc.data();
        return {
            subscriptionPaymentId: existingDoc.id,
            orderId: asString(data.razorpayOrderId),
            keyId: asString(process.env.RAZORPAY_KEY_ID),
            amountInPaise: asInt(data.amountInPaise),
            currency: asString(data.currency || DEFAULT_CURRENCY),
            planCode: plan.code,
            planTitle: plan.title,
            durationDays: plan.durationDays,
            idempotencyKey,
        };
    }
    const amountInPaise = plan.priceInRupees * 100;
    const order = await createRazorpayOrder(amountInPaise, DEFAULT_CURRENCY, `tenant_sub_${uid}_${Date.now()}`);
    const paymentRef = firebase_1.db.collection(TENANT_SUBSCRIPTION_COLLECTION).doc();
    await paymentRef.set({
        id: paymentRef.id,
        actorUid: uid,
        tenantId: uid,
        planCode: plan.code,
        planTitle: plan.title,
        durationDays: plan.durationDays,
        amountInPaise,
        currency: DEFAULT_CURRENCY,
        status: "pending",
        remoteStatus: "created",
        idempotencyKey,
        razorpayOrderId: order.orderId,
        razorpayPaymentId: null,
        razorpaySignatureHash: null,
        verifiedBy: null,
        verifiedAt: null,
        createdAt: firebase_1.FieldValue.serverTimestamp(),
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    });
    return {
        subscriptionPaymentId: paymentRef.id,
        orderId: order.orderId,
        keyId: order.keyId,
        amountInPaise,
        currency: DEFAULT_CURRENCY,
        planCode: plan.code,
        planTitle: plan.title,
        durationDays: plan.durationDays,
        idempotencyKey,
    };
});
exports.verifyTenantSubscriptionPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"],
}, async (request) => {
    const uid = requireAuthUid(request);
    await assertActorRoleOrThrow(request, uid, "tenant");
    await enforceAbuseLimit(request, uid, "tenant_subscription_verify");
    const subscriptionPaymentId = asString(request.data?.subscriptionPaymentId || request.data?.paymentId);
    const payload = (request.data?.payload ?? {});
    const razorpayOrderId = asString(request.data?.razorpayOrderId ?? payload.orderId);
    const razorpayPaymentId = asString(request.data?.razorpayPaymentId ?? payload.paymentId);
    const razorpaySignature = asString(request.data?.razorpaySignature ?? payload.signature);
    if (!subscriptionPaymentId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        throw new https_1.HttpsError("invalid-argument", "invalid-verification-payload");
    }
    const paymentRef = firebase_1.db.collection(TENANT_SUBSCRIPTION_COLLECTION).doc(subscriptionPaymentId);
    const snap = await paymentRef.get();
    if (!snap.exists)
        throw new https_1.HttpsError("not-found", "payment-not-found");
    const data = snap.data() ?? {};
    const actorUid = asString(data.actorUid);
    const tenantId = asString(data.tenantId);
    if (uid !== tenantId) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    if (actorUid && actorUid !== uid) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    if (asString(data.status).toLowerCase() === "paid") {
        throw new https_1.HttpsError("already-exists", "already-verified");
    }
    const verification = await verifyStoredRazorpayPayment({
        expectedOrderId: asString(data.razorpayOrderId),
        expectedAmountInPaise: asInt(data.amountInPaise),
        expectedCurrency: asString(data.currency || DEFAULT_CURRENCY),
        razorpayOrderId,
        razorpayPaymentId,
        razorpaySignature,
    });
    await paymentRef.set({
        status: "paid",
        remoteStatus: verification.remoteStatus,
        razorpayPaymentId,
        razorpaySignatureHash: verification.signatureHash,
        verifiedBy: uid,
        verifiedAt: firebase_1.FieldValue.serverTimestamp(),
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    const planCode = asString(data.planCode || "ad_free_1m");
    const plan = resolveTenantPlanOrThrow(planCode);
    const startDate = firebase_1.Timestamp.now();
    const expiryDate = firebase_1.Timestamp.fromDate(new Date(Date.now() + plan.durationDays * 24 * 60 * 60 * 1000));
    await firebase_1.db.collection("tenants").doc(uid).set({
        adSubscription: {
            planCode: plan.code,
            startDate,
            expiryDate,
        },
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        subscriptionPaymentId,
        tenantId: uid,
        status: "paid",
        planCode: plan.code,
        durationDays: plan.durationDays,
    };
});
(0, logger_1.logInfo)("paymentCallable module initialized", {
    region: REGION,
    monetizationCollections: [PAYMENT_COLLECTION, OWNER_SUBSCRIPTION_COLLECTION, TENANT_SUBSCRIPTION_COLLECTION],
});
//# sourceMappingURL=paymentCallable.js.map