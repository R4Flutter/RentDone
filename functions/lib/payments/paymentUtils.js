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
exports.loadPaymentFeeConfig = loadPaymentFeeConfig;
exports.calculateFeeBreakdownInPaise = calculateFeeBreakdownInPaise;
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../shared/logger");
const functions = __importStar(require("firebase-functions/v2"));
/**
 * Loads payment fee configuration from Firestore with hardcoded production overrides.
 */
async function loadPaymentFeeConfig(gateway = "razorpay") {
    const safeGateway = gateway.trim().toLowerCase();
    // Production policy lock: Razorpay convenience fee is fixed at 2%
    // with 18% GST on gateway fee (effective 2.36% on base rent).
    if (safeGateway === "razorpay") {
        return {
            gateway: safeGateway,
            gatewayPercent: 2,
            gatewayCostPercent: 2,
            gstPercent: 18,
        };
    }
    try {
        const cfgDoc = await firebase_1.db.collection("system_config").doc("payment_fee").get();
        if (cfgDoc.exists) {
            const data = cfgDoc.data();
            return {
                gateway: safeGateway,
                gatewayPercent: Number(data?.gatewayPercent || 2),
                gatewayCostPercent: Number(data?.gatewayCostPercent || 2),
                gstPercent: Number(data?.gstPercent || 18),
            };
        }
    }
    catch (error) {
        logger_1.AppLogger.warn("Falling back to default payment fee config", { gateway: safeGateway, error });
    }
    return {
        gateway: safeGateway,
        gatewayPercent: 2,
        gatewayCostPercent: 2,
        gstPercent: 18,
    };
}
/**
 * Calculates the exact fee breakdown for a rent payment.
 */
function calculateFeeBreakdownInPaise(params) {
    const rentAmount = Math.trunc(params.rentAmountInRupees);
    if (!Number.isFinite(rentAmount) || rentAmount <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Rent amount must be a positive integer in rupees");
    }
    const rentAmountInPaise = rentAmount * 100;
    const { gatewayPercent, gatewayCostPercent, gstPercent } = params.config;
    const gstBps = Math.round(gstPercent * 100);
    const gatewayBps = Math.round(gatewayPercent * 100);
    const gatewayCostBps = Math.round(gatewayCostPercent * 100);
    // FeeSTAGE calculation: Round upward to protect platform margins
    const feeNumerator = rentAmountInPaise * gatewayBps * (10000 + gstBps);
    const convenienceFeeInPaise = Math.max(1, Math.ceil(feeNumerator / (10000 * 10000)));
    const costNumerator = rentAmountInPaise * gatewayCostBps * (10000 + gstBps);
    const estimatedGatewayCostInPaise = Math.max(0, Math.ceil(costNumerator / (10000 * 10000)));
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
//# sourceMappingURL=paymentUtils.js.map