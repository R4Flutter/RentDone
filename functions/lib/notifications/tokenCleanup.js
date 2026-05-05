"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupExpiredSystemLogs = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../shared/logger");
/**
 * Daily cleanup of expired or orphan security and webhook data.
 */
exports.cleanupExpiredSystemLogs = (0, scheduler_1.onSchedule)({
    schedule: "0 3 * * *", // 3 AM UTC
    region: "asia-south1",
    memory: "256MiB",
}, async () => {
    const now = new Date();
    logger_1.AppLogger.info("Starting system log cleanup", { timestamp: now.toISOString() });
    const collections = ["_webhookEvents", "_securitySignals", "_notificationEvents"];
    for (const col of collections) {
        try {
            const snapshot = await firebase_1.db.collection(col)
                .where("expiresAt", "<=", now)
                .limit(500)
                .get();
            if (snapshot.empty)
                continue;
            const batch = firebase_1.db.batch();
            snapshot.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            logger_1.AppLogger.info(`Cleaned up ${snapshot.size} docs from ${col}`);
        }
        catch (error) {
            logger_1.AppLogger.error(`Failed to cleanup collection: ${col}`, error);
        }
    }
});
//# sourceMappingURL=tokenCleanup.js.map