"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkAndIncrementRateLimit = void 0;
const firebase_1 = require("../utils/firebase");
const DEFAULT_MAX_PER_DAY = {
    PAYMENT_RECEIVED: 20,
    RENT_DUE_REMINDER: 4,
};
const checkAndIncrementRateLimit = async (userId, notificationType) => {
    const dayKey = new Date().toISOString().slice(0, 10);
    const ref = firebase_1.db
        .collection("notificationRateLimits")
        .doc(`${userId}_${notificationType}_${dayKey}`);
    return firebase_1.db.runTransaction(async (txn) => {
        const snap = await txn.get(ref);
        const currentCount = snap.exists ? Number(snap.get("count") ?? 0) : 0;
        const maxPerDay = DEFAULT_MAX_PER_DAY[notificationType] ?? 10;
        if (currentCount >= maxPerDay) {
            return false;
        }
        txn.set(ref, {
            userId,
            type: notificationType,
            count: currentCount + 1,
            maxPerDay,
            dayKey,
            updatedAt: firebase_1.FieldValue.serverTimestamp(),
            createdAt: snap.exists ? snap.get("createdAt") ?? firebase_1.FieldValue.serverTimestamp() : firebase_1.FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
    });
};
exports.checkAndIncrementRateLimit = checkAndIncrementRateLimit;
//# sourceMappingURL=rateLimitService.js.map