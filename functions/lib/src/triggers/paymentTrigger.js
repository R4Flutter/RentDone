"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPaymentCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_1 = require("../utils/firebase");
const rateLimitService_1 = require("../services/rateLimitService");
const notificationService_1 = require("../services/notificationService");
const tokenService_1 = require("../services/tokenService");
const validationService_1 = require("../services/validationService");
const logger_1 = require("../utils/logger");
const normalizeStatus = (value) => String(value ?? "").trim().toLowerCase();
const inr = (value) => new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value);
exports.onPaymentCreated = (0, firestore_1.onDocumentCreated)({
    document: "payments/{paymentId}",
    region: "asia-south1",
    maxInstances: 20,
    retry: true,
}, async (event) => {
    const paymentId = event.params.paymentId;
    const payment = event.data?.data();
    if (!payment) {
        return;
    }
    const status = normalizeStatus(payment.status);
    if (status !== "paid" && status !== "success") {
        (0, logger_1.logInfo)("Skipping payment notification for non-paid status", { paymentId, status });
        return;
    }
    try {
        const validated = await (0, validationService_1.validatePaymentForNotification)(payment);
        if (!validated.valid) {
            (0, logger_1.logWarn)("Payment notification skipped after validation", { paymentId });
            return;
        }
        const eventId = `payment_received_${paymentId}`;
        const reserved = await (0, notificationService_1.reserveNotificationEvent)(eventId, {
            type: "PAYMENT_RECEIVED",
            ownerId: validated.ownerId,
            tenantId: validated.tenantId,
            paymentId,
        });
        if (!reserved) {
            (0, logger_1.logInfo)("Duplicate payment notification prevented", { eventId });
            return;
        }
        const withinRateLimit = await (0, rateLimitService_1.checkAndIncrementRateLimit)(validated.ownerId, "PAYMENT_RECEIVED");
        if (!withinRateLimit) {
            (0, logger_1.logWarn)("Payment notification rate-limited", {
                ownerId: validated.ownerId,
                paymentId,
            });
            return;
        }
        const tokenBundle = await (0, tokenService_1.getUserDeviceTokens)(validated.ownerId);
        if (tokenBundle.tokens.length === 0) {
            (0, logger_1.logInfo)("No owner tokens available for payment notification", {
                ownerId: validated.ownerId,
                paymentId,
            });
            return;
        }
        const title = "Payment Received";
        const body = `Rs ${inr(validated.amount)} received from ${validated.tenantName}`;
        const payload = {
            type: "PAYMENT_RECEIVED",
            title,
            body,
            data: {
                type: "PAYMENT_RECEIVED",
                tenantId: validated.tenantId,
                paymentId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
        };
        const dispatch = await (0, notificationService_1.sendMulticastWithRetry)(tokenBundle.tokens, payload);
        await (0, tokenService_1.cleanupInvalidTokens)(tokenBundle.tokenRefs, dispatch.invalidTokens);
        await Promise.all([
            firebase_1.db.collection("messages").doc(eventId).set({
                type: "PAYMENT_RECEIVED",
                ownerId: validated.ownerId,
                tenantId: validated.tenantId,
                paymentId,
                title,
                body,
                read: false,
                severity: "info",
                createdAt: firebase_1.FieldValue.serverTimestamp(),
            }),
            (0, notificationService_1.trackNotificationAnalytics)({
                userId: validated.ownerId,
                type: "PAYMENT_RECEIVED",
                eventId,
                sentCount: dispatch.sentCount,
                invalidTokenCount: dispatch.invalidTokens.length,
            }),
        ]);
        (0, logger_1.logInfo)("Payment notification dispatched", {
            paymentId,
            ownerId: validated.ownerId,
            sentCount: dispatch.sentCount,
        });
    }
    catch (error) {
        (0, logger_1.logError)("onPaymentCreated failed", {
            paymentId,
            error: error instanceof Error ? error.message : String(error),
        });
    }
});
//# sourceMappingURL=paymentTrigger.js.map