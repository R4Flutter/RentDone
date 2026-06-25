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
exports.createRazorpayOrder = void 0;
const https_1 = require("firebase-functions/v2/https");
const functions = __importStar(require("firebase-functions"));
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
        // 1. Idempotency Check: Return existing order if already created
        if (paymentData?.razorpayOrderId) {
            logger_1.AppLogger.info("Returning existing Razorpay order", { paymentId, orderId: paymentData.razorpayOrderId });
            return {
                orderId: paymentData.razorpayOrderId,
                keyId: paymentData.razorpayKeyId || functions.config().razorpay.key_id,
                amount: paymentData.totalPayablePaise || paymentData.amount,
                currency: "INR",
            };
        }
        const baseAmount = Number(paymentData?.baseAmount || paymentData?.amount);
        const config = await (0, paymentUtils_1.loadPaymentFeeConfig)("razorpay");
        const breakdown = (0, paymentUtils_1.calculateFeeBreakdownInPaise)({
            rentAmountInRupees: baseAmount,
            config,
        });
        // 2. Secure Secrets: Fetch Razorpay credentials from Firebase config
        const razorConfig = functions.config().razorpay;
        const keyId = razorConfig?.key_id || "";
        const keySecret = razorConfig?.key_secret || "";
        if (!keyId || !keySecret) {
            logger_1.AppLogger.error("Razorpay credentials missing in functions config");
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