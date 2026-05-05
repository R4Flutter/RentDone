"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendRentDueReminders = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../shared/logger");
const sendNotification_1 = require("../notifications/sendNotification");
/**
 * Daily scheduler to remind tenants about upcoming rent due dates.
 */
exports.sendRentDueReminders = (0, scheduler_1.onSchedule)({
    schedule: "0 9 * * *", // 9 AM IST (approx)
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
}, async () => {
    const today = new Date();
    const day = today.getDate();
    logger_1.AppLogger.info("Running rent due reminders", { day });
    try {
        // 1. Fetch active tenants whose rent is due today
        const tenantsSnap = await firebase_1.db.collection("tenants")
            .where("isActive", "==", true)
            .where("rentDueDay", "==", day)
            .get();
        if (tenantsSnap.empty) {
            logger_1.AppLogger.info("No tenants due today");
            return;
        }
        for (const doc of tenantsSnap.docs) {
            const tenant = doc.data();
            const uid = tenant.authUid;
            if (!uid)
                continue;
            // 2. Fetch user device tokens
            const userDoc = await firebase_1.db.collection("users").doc(uid).get();
            const fcmToken = userDoc.data()?.fcmToken;
            if (!fcmToken)
                continue;
            const title = "Rent Due Today";
            const body = `Hi ${tenant.name}, your rent of ₹${tenant.rentAmount} is due today.`;
            // 3. Send notification
            await (0, sendNotification_1.sendMulticastNotification)([fcmToken], {
                title,
                body,
                data: {
                    type: "RENT_DUE",
                    tenantId: doc.id,
                }
            });
            // 4. Record in-app history
            await (0, sendNotification_1.recordInAppMessage)({
                id: `rent_due_${doc.id}_${today.getTime()}`,
                tenantUserId: uid,
                tenantId: doc.id,
                ownerId: tenant.ownerId,
                title,
                body,
                type: "RENT_DUE",
                severity: "info",
            });
        }
    }
    catch (error) {
        logger_1.AppLogger.error("Rent reminder scheduler failed", error);
    }
});
//# sourceMappingURL=rentReminder.js.map