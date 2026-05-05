"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createRazorpayOrder = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../shared/logger");
const paymentUtils_1 = require("./paymentUtils");
/**
 * Creates a Razorpay order for an existing payment record.
 * Validates ownership and applies convenience fees.
 */
exports.createRazorpayOrder = (0, https_1.onCall)({
    region: "asia-south1",
    enforceAppCheck: true,
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const { paymentId } = request.data;
    if (!paymentId) {
        throw new https_1.HttpsError("invalid-argument", "paymentId is required");
    }
    logger_1.AppLogger.info("Initiating Razorpay order creation", { uid, paymentId });
    try {
        const paymentRef = firebase_1.db.collection("payments").doc(paymentId);
        const paymentDoc = await paymentRef.get();
        if (!paymentDoc.exists) {
            throw new https_1.HttpsError("not-found", "Payment record not found");
        }
        const paymentData = paymentDoc.data();
        if (paymentData?.tenantId !== uid) {
            logger_1.AppLogger.warn("Unauthorized order creation attempt", { uid, paymentId });
            throw new https_1.HttpsError("permission-denied", "You are not authorized to pay this record");
        }
        if (paymentData?.status === "paid") {
            throw new https_1.HttpsError("failed-precondition", "Payment is already completed");
        }
        const baseAmount = Number(paymentData?.baseAmount || paymentData?.amount);
        const config = await (0, paymentUtils_1.loadPaymentFeeConfig)("razorpay");
        const breakdown = (0, paymentUtils_1.calculateFeeBreakdownInPaise)({
            rentAmountInRupees: baseAmount,
            config,
        });
        // Fetch Razorpay credentials from environment/config
        const keyId = process.env.RAZORPAY_KEY_ID || "";
        const keySecret = process.env.RAZORPAY_KEY_SECRET || "";
        if (!keyId || !keySecret) {
            logger_1.AppLogger.error("Razorpay credentials missing in environment");
            throw new https_1.HttpsError("internal", "Payment gateway misconfigured");
        }
        const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
        const orderRes = await fetch("https://api.razorpay.com/v1/orders", {
            method: "POST",
            headers: {
                Authorization: `Basic ${auth}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                amount: breakdown.totalPayableInPaise,
                currency: "INR",
                receipt: paymentId,
                notes: {
                    tenantId: uid,
                    paymentId,
                    convenienceFee: breakdown.convenienceFeeInPaise,
                },
            }),
        });
        if (!orderRes.ok) {
            const errorText = await orderRes.text();
            logger_1.AppLogger.error("Razorpay API failure", { status: orderRes.status, errorText });
            throw new https_1.HttpsError("internal", "Gateway order creation failed");
        }
        const order = await orderRes.json();
        // Atomically link order ID to payment record
        await paymentRef.update({
            razorpayOrderId: order.id,
            razorpayKeyId: keyId,
            convenienceFeePaise: breakdown.convenienceFeeInPaise,
            totalPayablePaise: breakdown.totalPayableInPaise,
            updatedAt: firebase_1.FieldValue.serverTimestamp(),
        });
        return {
            orderId: order.id,
            keyId,
            amount: breakdown.totalPayableInPaise,
            currency: "INR",
        };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError)
            throw error;
        logger_1.AppLogger.error("Unexpected error in createRazorpayOrder", error, { paymentId });
        throw new https_1.HttpsError("internal", "Internal processing error");
    }
});
//# sourceMappingURL=createOrder.js.map