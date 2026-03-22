"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendRentDueReminders = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firebase_1 = require("../utils/firebase");
const rateLimitService_1 = require("../services/rateLimitService");
const notificationService_1 = require("../services/notificationService");
const tokenService_1 = require("../services/tokenService");
const logger_1 = require("../utils/logger");
const toIstNow = () => new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
const dueDateKey = (date) => {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
};
const statusString = (value) => String(value ?? "").trim().toLowerCase();
const buildRentDueBody = (amount) => {
    const value = Number.isFinite(amount) ? amount : 0;
    return `Your rent of Rs ${new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value)} is due today.`;
};
const getTenantUserId = (tenant, tenantDocId) => {
    const authUid = String(tenant.authUid ?? "").trim();
    if (authUid) {
        return authUid;
    }
    return tenantDocId;
};
const loadDueTenants = async (today) => {
    const day = today.getDate();
    const start = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0, 0);
    const end = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 23, 59, 59, 999);
    const [dueDaySnap, dueDateSnap] = await Promise.all([
        firebase_1.db.collection("tenants").where("isActive", "==", true).where("rentDueDay", "==", day).get(),
        firebase_1.db.collection("tenants").where("isActive", "==", true).where("dueDate", ">=", start).where("dueDate", "<=", end).get(),
    ]);
    const deduped = new Map();
    dueDaySnap.docs.forEach((doc) => deduped.set(doc.id, doc));
    dueDateSnap.docs.forEach((doc) => deduped.set(doc.id, doc));
    return [...deduped.values()];
};
exports.sendRentDueReminders = (0, scheduler_1.onSchedule)({
    schedule: "0 9 * * *",
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
    retryCount: 2,
    maxRetrySeconds: 300,
}, async () => {
    const today = toIstNow();
    const dateKey = dueDateKey(today);
    try {
        const dueTenantDocs = await loadDueTenants(today);
        if (dueTenantDocs.length === 0) {
            (0, logger_1.logInfo)("No tenants due today", { dateKey });
            return;
        }
        let sentCount = 0;
        let processed = 0;
        for (const tenantDoc of dueTenantDocs) {
            const tenant = tenantDoc.data();
            const tenantUserId = getTenantUserId(tenant, tenantDoc.id);
            const ownerId = String(tenant.ownerId ?? "").trim();
            const tenantStatus = statusString(tenant.status);
            if (!tenantUserId || !ownerId || (tenantStatus && tenantStatus !== "active")) {
                continue;
            }
            const eventId = `rent_due_${tenantDoc.id}_${dateKey}`;
            const reserved = await (0, notificationService_1.reserveNotificationEvent)(eventId, {
                type: "RENT_DUE_REMINDER",
                tenantId: tenantDoc.id,
                tenantUserId,
                ownerId,
                dateKey,
            });
            if (!reserved) {
                continue;
            }
            const withinRateLimit = await (0, rateLimitService_1.checkAndIncrementRateLimit)(tenantUserId, "RENT_DUE_REMINDER");
            if (!withinRateLimit) {
                (0, logger_1.logWarn)("Tenant rent reminder rate-limited", { tenantUserId, eventId });
                continue;
            }
            const tokenBundle = await (0, tokenService_1.getUserDeviceTokens)(tenantUserId);
            if (tokenBundle.tokens.length === 0) {
                continue;
            }
            const amount = Number(tenant.rentAmount ?? tenant.monthlyRent ?? 0);
            const payload = {
                type: "RENT_DUE_REMINDER",
                title: "Rent Due Reminder",
                body: buildRentDueBody(amount),
                data: {
                    type: "RENT_DUE_REMINDER",
                    tenantId: tenantDoc.id,
                    ownerId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
            };
            const dispatch = await (0, notificationService_1.sendMulticastWithRetry)(tokenBundle.tokens, payload);
            await (0, tokenService_1.cleanupInvalidTokens)(tokenBundle.tokenRefs, dispatch.invalidTokens);
            await Promise.all([
                firebase_1.db.collection("messages").doc(eventId).set({
                    type: "RENT_DUE_REMINDER",
                    title: payload.title,
                    body: payload.body,
                    ownerId,
                    tenantId: tenantDoc.id,
                    read: false,
                    severity: "warning",
                    createdAt: firebase_1.FieldValue.serverTimestamp(),
                }),
                (0, notificationService_1.trackNotificationAnalytics)({
                    userId: tenantUserId,
                    type: "RENT_DUE_REMINDER",
                    eventId,
                    sentCount: dispatch.sentCount,
                    invalidTokenCount: dispatch.invalidTokens.length,
                }),
            ]);
            sentCount += dispatch.sentCount;
            processed += 1;
        }
        (0, logger_1.logInfo)("sendRentDueReminders completed", {
            dateKey,
            processed,
            sentCount,
        });
    }
    catch (error) {
        (0, logger_1.logError)("sendRentDueReminders failed", {
            dateKey,
            error: error instanceof Error ? error.message : String(error),
        });
    }
});
//# sourceMappingURL=rentReminderScheduler.js.map