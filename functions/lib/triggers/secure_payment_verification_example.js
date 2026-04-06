"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyPaymentSecureExample = void 0;
const https_1 = require("firebase-functions/v2/https");
const node_crypto_1 = require("node:crypto");
const firebase_1 = require("../utils/firebase");
const REGION = "asia-south1";
const asString = (value) => String(value ?? "").trim();
const asInt = (value) => {
    const parsed = Number(value ?? 0);
    if (!Number.isFinite(parsed)) {
        return 0;
    }
    return Math.trunc(parsed);
};
/**
 * Reference implementation for secure Razorpay verification.
 * Flow: client checkout -> callable verify -> backend validation -> backend write.
 */
exports.verifyPaymentSecureExample = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
    secrets: ["RAZORPAY_KEY", "RAZORPAY_SECRET"],
}, async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "unauthenticated");
    }
    const paymentId = asString(request.data?.paymentId);
    const razorpayOrderId = asString(request.data?.razorpayOrderId);
    const razorpayPaymentId = asString(request.data?.razorpayPaymentId);
    const razorpaySignature = asString(request.data?.razorpaySignature);
    if (!paymentId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        throw new https_1.HttpsError("invalid-argument", "invalid-verification-payload");
    }
    const paymentRef = firebase_1.db.collection("payments").doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
        throw new https_1.HttpsError("not-found", "payment-not-found");
    }
    const payment = paymentDoc.data() ?? {};
    const ownerId = asString(payment.ownerId);
    const tenantId = asString(payment.tenantId);
    // Restrict verify caller to the payment participants only.
    if (callerUid !== ownerId && callerUid !== tenantId) {
        throw new https_1.HttpsError("permission-denied", "unauthorized");
    }
    const storedOrderId = asString(payment.razorpayOrderId);
    if (!storedOrderId || storedOrderId !== razorpayOrderId) {
        throw new https_1.HttpsError("failed-precondition", "order-mismatch");
    }
    const keyId = asString(process.env.RAZORPAY_KEY);
    const keySecret = asString(process.env.RAZORPAY_SECRET);
    if (!keyId || !keySecret) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-secret-missing");
    }
    // 1) Verify signature integrity.
    const expectedSignature = (0, node_crypto_1.createHmac)("sha256", keySecret)
        .update(`${razorpayOrderId}|${razorpayPaymentId}`)
        .digest("hex");
    const provided = Buffer.from(razorpaySignature);
    const expected = Buffer.from(expectedSignature);
    if (provided.length !== expected.length || !(0, node_crypto_1.timingSafeEqual)(provided, expected)) {
        throw new https_1.HttpsError("permission-denied", "invalid-signature");
    }
    // 2) Fetch payment from Razorpay and validate order/amount/currency/status.
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
    const expectedAmount = asInt(payment.amountInPaise ?? (asInt(payment.amount) * 100));
    const expectedCurrency = asString(payment.currency || "INR").toUpperCase();
    if (remoteOrderId !== razorpayOrderId) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-order-validation-failed");
    }
    if (remoteAmount !== expectedAmount) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-amount-validation-failed");
    }
    if (remoteCurrency !== expectedCurrency) {
        throw new https_1.HttpsError("failed-precondition", "razorpay-currency-validation-failed");
    }
    if (remoteStatus !== "captured") {
        throw new https_1.HttpsError("failed-precondition", `payment-not-captured:${remoteStatus}`);
    }
    // 3) Write payment result from backend only.
    await paymentRef.set({
        status: "paid",
        method: "razorpay",
        paidAmount: Math.trunc(expectedAmount / 100),
        remainingAmount: 0,
        transactionId: razorpayPaymentId,
        razorpayOrderId,
        razorpaySignature,
        verifiedBy: callerUid,
        verifiedAt: firebase_1.FieldValue.serverTimestamp(),
        updatedAt: firebase_1.FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
        ok: true,
        paymentId,
        status: "paid",
        amountInPaise: expectedAmount,
        currency: expectedCurrency,
    };
});
//# sourceMappingURL=secure_payment_verification_example.js.map