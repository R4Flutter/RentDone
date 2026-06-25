"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyPayment = exports.updatePaymentStatus = exports.createPayment = void 0;
const https_1 = require("firebase-functions/v2/https");
const functions = __importStar(require("firebase-functions"));
const node_crypto_1 = require("node:crypto");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../utils/logger");
const REGION = "asia-south1";
const MIN_PAYMENT_AMOUNT = 1;
const MAX_PAYMENT_AMOUNT = 5_000_000;
const asString = (value) => String(value ?? "").trim();
const asInt = (value) => {
    const parsed = Number(value ?? 0);
    if (!Number.isFinite(parsed))
        return 0;
    return Math.trunc(parsed);
};
const normalizeMethod = (value) => {
    const method = asString(value).toLowerCase();
    if (method === "manual" || method === "razorpay")
        return method;
    return null;
};
const assertAmountOrThrow = (amount) => {
    if (!Number.isInteger(amount) || amount < MIN_PAYMENT_AMOUNT || amount > MAX_PAYMENT_AMOUNT) {
        throw new https_1.HttpsError("invalid-argument", "invalid-amount");
    }
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
exports.createPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "unauthenticated");
    }
    const tenantId = asString(request.data?.tenantId);
    const propertyId = asString(request.data?.propertyId);
    const idempotencyKey = asString(request.data?.idempotencyKey);
    const method = normalizeMethod(request.data?.method);
    const amount = asInt(request.data?.amount);
    if (!tenantId || !propertyId || !idempotencyKey || !method) {
        throw new https_1.HttpsError("invalid-argument", "invalid-request");
    }
    assertAmountOrThrow(amount);
    await logPaymentEvent("PAYMENT_CREATE_ATTEMPT", {
        tenantId,
        propertyId,
        actorUid: uid,
        amount,
        method,
        idempotencyKey,
    });
    try {
        const { ownerId } = await assertAccessAndOwnership(uid, tenantId, propertyId);
        const existingByIdempotency = await firebase_1.db
            .collection("payments")
            .where("idempotencyKey", "==", idempotencyKey)
            .limit(1)
            .get();
        if (!existingByIdempotency.empty) {
            const existing = existingByIdempotency.docs[0];
            const existingData = existing.data();
            return {
                paymentId: existing.id,
                status: asString(existingData.status).toLowerCase() || "pending",
                idempotent: true,
            };
        }
        const duplicateCutoff = firebase_1.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 1000));
        const duplicates = await firebase_1.db
            .collection("payments")
            .where("tenantId", "==", tenantId)
            .where("baseAmount", "==", amount)
            .where("createdAt", ">=", duplicateCutoff)
            .limit(1)
            .get();
        if (!duplicates.empty) {
            await logPaymentEvent("PAYMENT_CREATE_FAILED", {
                tenantId,
                ownerId,
                amount,
                method,
                errorReason: "duplicate-payment",
            });
            throw new https_1.HttpsError("already-exists", "duplicate-payment");
        }
        const paymentRef = firebase_1.db.collection("payments").doc();
        const paidAmount = method === "manual" ? amount : 0;
        const remainingAmount = amount - paidAmount;
        const status = method === "manual" ? "paid" : "pending";
        await firebase_1.db.runTransaction(async (tx) => {
            tx.set(paymentRef, {
                id: paymentRef.id,
                tenantId,
                ownerId,
                propertyId,
                amount,
                baseAmount: amount,
                paidAmount,
                remainingAmount,
                status,
                method,
                currency: "INR",
                idempotencyKey,
                installments: method === "manual"
                    ? [
                        {
                            amount,
                            date: firebase_1.FieldValue.serverTimestamp(),
                            method: "manual",
                            notes: "manual payment",
                        },
                    ]
                    : [],
                date: firebase_1.FieldValue.serverTimestamp(),
                createdAt: firebase_1.FieldValue.serverTimestamp(),
                updatedAt: firebase_1.FieldValue.serverTimestamp(),
            });
        });
        const createdDoc = await paymentRef.get();
        const created = createdDoc.data();
        if (!createdDoc.exists || !created) {
            throw new https_1.HttpsError("internal", "internal-error");
        }
        const baseAmount = asInt(created.baseAmount);
        const paid = asInt(created.paidAmount);
        const remaining = asInt(created.remainingAmount);
        if (baseAmount <= 0 || paid + remaining !== baseAmount) {
            throw new https_1.HttpsError("internal", "integrity-check-failed");
        }
        await logPaymentEvent("PAYMENT_CREATE_SUCCESS", {
            paymentId: paymentRef.id,
            tenantId,
            ownerId,
            amount,
            method,
        });
        return { paymentId: paymentRef.id, status, idempotent: false };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        (0, logger_1.logError)("createPayment failed", {
            actorUid: uid,
            tenantId,
            propertyId,
            amount,
            method,
            error: error instanceof Error ? error.message : String(error),
        });
        await logPaymentEvent("PAYMENT_CREATE_FAILED", {
            tenantId,
            propertyId,
            amount,
            method,
            errorReason: error instanceof Error ? error.message : String(error),
        });
        throw new https_1.HttpsError("internal", "internal-error");
    }
});
exports.updatePaymentStatus = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "unauthenticated");
    }
    const paymentId = asString(request.data?.paymentId);
    const requestedStatus = asString(request.data?.newStatus).toLowerCase();
    const installmentAmount = asInt(request.data?.installmentAmount);
    const installmentMethod = asString(request.data?.installmentMethod || "manual").toLowerCase();
    const installmentNotes = asString(request.data?.installmentNotes);
    if (!paymentId || !["paid", "partial", "unpaid"].includes(requestedStatus)) {
        throw new https_1.HttpsError("invalid-argument", "invalid-status");
    }
    const paymentRef = firebase_1.db.collection("payments").doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
        throw new https_1.HttpsError("not-found", "payment-not-found");
    }
    const data = paymentDoc.data() ?? {};
    const ownerId = asString(data.ownerId);
    if (uid !== ownerId) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
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
exports.verifyPayment = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "unauthenticated");
    }
    const paymentId = asString(request.data?.paymentId);
    const legacyPayload = (request.data?.payload ?? {});
    const razorpayPaymentId = asString(request.data?.razorpayPaymentId ?? legacyPayload.paymentId);
    const razorpaySignature = asString(request.data?.razorpaySignature ?? legacyPayload.signature);
    const razorpayOrderId = asString(request.data?.razorpayOrderId ?? legacyPayload.orderId);
    if (!paymentId || !razorpayPaymentId || !razorpaySignature || !razorpayOrderId) {
        throw new https_1.HttpsError("invalid-argument", "invalid-verification-payload");
    }
    const paymentRef = firebase_1.db.collection("payments").doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
        throw new https_1.HttpsError("not-found", "payment-not-found");
    }
    const paymentData = paymentDoc.data() ?? {};
    const ownerId = asString(paymentData.ownerId);
    const tenantId = asString(paymentData.tenantId);
    const baseAmount = asInt(paymentData.baseAmount ?? paymentData.amount);
    if (uid !== ownerId && uid !== tenantId) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    const razorConfig = functions.config().razorpay;
    const razorpaySecret = asString(razorConfig?.key_secret || razorConfig?.secret);
    if (!razorpaySecret) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-secret-missing");
    }
    const expectedSignature = (0, node_crypto_1.createHmac)("sha256", razorpaySecret)
        .update(`${razorpayOrderId}|${razorpayPaymentId}`)
        .digest("hex");
    const provided = Buffer.from(razorpaySignature);
    const expected = Buffer.from(expectedSignature);
    if (provided.length !== expected.length || !(0, node_crypto_1.timingSafeEqual)(provided, expected)) {
        await logPaymentEvent("PAYMENT_VERIFY_FAILED", {
            paymentId,
            tenantId,
            ownerId,
            errorReason: "invalid-signature",
        });
        throw new https_1.HttpsError("permission-denied", "invalid-signature");
    }
    await paymentRef.update({
        status: "paid",
        method: "razorpay",
        paidAmount: baseAmount,
        remainingAmount: 0,
        transactionId: razorpayPaymentId,
        razorpayOrderId,
        razorpaySignature,
        completedAt: firebase_1.FieldValue.serverTimestamp(),
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    });
    await logPaymentEvent("PAYMENT_VERIFY_SUCCESS", {
        paymentId,
        tenantId,
        ownerId,
        amount: baseAmount,
        method: "razorpay",
    });
    (0, logger_1.logInfo)("Payment verified", {
        paymentId,
        tenantId,
        ownerId,
        actorUid: uid,
    });
    return {
        paymentId,
        status: "paid",
        paidAmount: baseAmount,
        remainingAmount: 0,
    };
});
//# sourceMappingURL=paymentCallable.js.map