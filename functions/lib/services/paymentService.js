"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyRazorpayPayment = verifyRazorpayPayment;
const node_crypto_1 = require("node:crypto");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../utils/logger");
const asString = (value) => String(value ?? "").trim();
const asInt = (value) => {
    const parsed = Number(value ?? 0);
    if (!Number.isFinite(parsed))
        return 0;
    return Math.trunc(parsed);
};
async function verifyRazorpayPayment(params) {
    const { paymentId, razorpayOrderId, razorpayPaymentId, razorpaySignature, actorUid } = params;
    const paymentRef = firebase_1.db.collection("payments").doc(paymentId);
    const paymentDoc = await paymentRef.get();
    if (!paymentDoc.exists) {
        throw new Error("payment-not-found");
    }
    const payment = paymentDoc.data() ?? {};
    const ownerId = asString(payment.ownerId);
    const tenantId = asString(payment.tenantId);
    const storedOrderId = asString(payment.razorpayOrderId);
    if (actorUid !== ownerId && actorUid !== tenantId) {
        throw new Error("unauthorized");
    }
    if (!storedOrderId || storedOrderId !== razorpayOrderId) {
        throw new Error("order-mismatch");
    }
    const keyId = asString(process.env.RAZORPAY_KEY_ID);
    const keySecret = asString(process.env.RAZORPAY_KEY_SECRET || process.env.RAZORPAY_SECRET);
    if (!keyId || !keySecret) {
        throw new Error("razorpay-secret-missing");
    }
    // 1) Verify signature integrity.
    try {
        const expectedSignature = (0, node_crypto_1.createHmac)("sha256", keySecret)
            .update(`${razorpayOrderId}|${razorpayPaymentId}`)
            .digest("hex");
        const provided = Buffer.from(razorpaySignature);
        const expected = Buffer.from(expectedSignature);
        if (provided.length !== expected.length || !(0, node_crypto_1.timingSafeEqual)(provided, expected)) {
            await (0, logger_1.logWarn)("Payment verification failed - invalid signature", {
                paymentId,
                razorpayOrderId,
                razorpayPaymentId,
            });
            throw new Error("invalid-signature");
        }
    }
    catch (err) {
        throw err;
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
        (0, logger_1.logError)("Razorpay fetch failed", { paymentId, body });
        throw new Error(`razorpay-fetch-failed:${body}`);
    }
    const remote = (await response.json());
    const remoteOrderId = asString(remote.order_id);
    const remoteAmount = asInt(remote.amount);
    const remoteCurrency = asString(remote.currency).toUpperCase();
    const remoteStatus = asString(remote.status).toLowerCase();
    const expectedAmount = asInt(payment.amountInPaise ?? (asInt(payment.amount) * 100));
    const expectedCurrency = asString(payment.currency || "INR").toUpperCase();
    if (remoteOrderId !== razorpayOrderId) {
        throw new Error("razorpay-order-validation-failed");
    }
    if (remoteAmount !== expectedAmount) {
        throw new Error("razorpay-amount-validation-failed");
    }
    if (remoteCurrency !== expectedCurrency) {
        throw new Error("razorpay-currency-validation-failed");
    }
    if (remoteStatus !== "captured") {
        throw new Error(`payment-not-captured:${remoteStatus}`);
    }
    // 3) Write payment result from backend only. Store only a hash of signature.
    const signatureHash = (0, node_crypto_1.createHmac)("sha256", keySecret)
        .update(String(razorpaySignature || ""))
        .digest("hex");
    const paidAt = firebase_1.Timestamp.now();
    const paidDate = paidAt.toDate();
    const receiptNumber = `RCP-${paidDate.getFullYear()}${String(paidDate.getMonth() + 1).padStart(2, "0")}-${paymentId.slice(-6).toUpperCase()}`;
    await paymentRef.set({
        status: "paid",
        method: "razorpay",
        remoteStatus,
        paidAmount: Math.trunc(expectedAmount / 100),
        remainingAmount: 0,
        transactionId: razorpayPaymentId,
        razorpayPaymentId,
        razorpayOrderId,
        razorpaySignatureHash: signatureHash,
        verifiedBy: actorUid,
        verifiedAt: firebase_1.FieldValue.serverTimestamp(),
        date: paidAt,
        paymentDate: paidAt,
        paidAt,
        completedAt: paidAt,
        month: paidDate.getMonth() + 1,
        year: paidDate.getFullYear(),
        receiptNumber,
        updatedAt: paidAt,
        amountInPaise: expectedAmount,
        totalPayableInPaise: expectedAmount,
        currency: expectedCurrency,
    }, { merge: true });
    await (0, logger_1.logInfo)("PAYMENT_VERIFY_SUCCESS", {
        paymentId,
        tenantId: payment.tenantId,
        ownerId: payment.ownerId,
        amount: expectedAmount,
        method: "razorpay",
    });
    return {
        paymentId,
        status: "paid",
        paidAmount: Math.trunc(expectedAmount / 100),
        remainingAmount: 0,
        amountInPaise: expectedAmount,
        currency: expectedCurrency,
    };
}
exports.default = {
    verifyRazorpayPayment,
};
//# sourceMappingURL=paymentService.js.map