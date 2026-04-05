"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.trackNotificationAnalytics = exports.sendMulticastWithRetry = exports.updateNotificationEventStatus = exports.reserveNotificationEvent = void 0;
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../utils/logger");
const FCM_BATCH_SIZE = 500;
const MAX_RETRY_ATTEMPTS = 2;
const isInvalidTokenError = (code) => code.includes("registration-token-not-registered") ||
    code.includes("invalid-registration-token") ||
    code.includes("mismatch-credential");
const isTransientError = (code) => code.includes("internal") ||
    code.includes("unavailable") ||
    code.includes("deadline-exceeded") ||
    code.includes("resource-exhausted") ||
    code.includes("unknown");
const sleep = async (ms) => new Promise((resolve) => {
    setTimeout(resolve, ms);
});
const reserveNotificationEvent = async (eventKey, payload) => {
    const ref = firebase_1.db.collection("_notificationEvents").doc(eventKey);
    try {
        await ref.create({
            ...payload,
            status: "reserved",
            reservedAt: firebase_1.FieldValue.serverTimestamp(),
            createdAt: firebase_1.FieldValue.serverTimestamp(),
            expiresAt: firebase_1.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
        });
        return true;
    }
    catch (error) {
        const errorText = error instanceof Error ? error.message.toLowerCase() : String(error).toLowerCase();
        if (errorText.includes("already exists")) {
            return false;
        }
        throw error;
    }
};
exports.reserveNotificationEvent = reserveNotificationEvent;
const updateNotificationEventStatus = async (eventKey, status, payload) => {
    try {
        await firebase_1.db.collection("_notificationEvents").doc(eventKey).set({
            status,
            ...(status === "sent"
                ? { sentAt: firebase_1.FieldValue.serverTimestamp() }
                : { failedAt: firebase_1.FieldValue.serverTimestamp() }),
            ...(payload ?? {}),
            updatedAt: firebase_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (error) {
        (0, logger_1.logError)("updateNotificationEventStatus failed", {
            eventKey,
            status,
            error: error instanceof Error ? error.message : String(error),
        });
        throw error;
    }
};
exports.updateNotificationEventStatus = updateNotificationEventStatus;
const sendChunk = async (tokens, payload) => {
    const invalidTokens = [];
    const retryTokens = [];
    let sentCount = 0;
    const response = await firebase_1.messaging.sendEachForMulticast({
        tokens,
        notification: {
            title: payload.title,
            body: payload.body,
        },
        data: payload.data,
        android: {
            priority: "high",
            notification: {
                channelId: "rentdone_high_priority",
                sound: "default",
            },
        },
        apns: {
            headers: {
                "apns-priority": "10",
            },
            payload: {
                aps: {
                    sound: "default",
                },
            },
        },
    });
    sentCount += response.successCount;
    response.responses.forEach((entry, index) => {
        if (entry.success) {
            return;
        }
        const code = String(entry.error?.code ?? "").toLowerCase();
        if (isInvalidTokenError(code)) {
            invalidTokens.push(tokens[index]);
            return;
        }
        if (isTransientError(code)) {
            retryTokens.push(tokens[index]);
            return;
        }
        (0, logger_1.logWarn)("Non-retryable FCM error", {
            code,
            message: entry.error?.message,
            type: payload.type,
        });
    });
    return {
        sentCount,
        invalidTokens,
        transientFailures: retryTokens.length,
        retryTokens,
    };
};
const sendMulticastWithRetry = async (tokens, payload) => {
    const deduped = [...new Set(tokens.filter((token) => token.trim().length > 0))];
    if (deduped.length === 0) {
        return { sentCount: 0, invalidTokens: [], transientFailures: 0 };
    }
    const invalidTokens = [];
    let sentCount = 0;
    let transientFailures = 0;
    for (let index = 0; index < deduped.length; index += FCM_BATCH_SIZE) {
        const chunk = deduped.slice(index, index + FCM_BATCH_SIZE);
        let pending = [...chunk];
        let attempt = 0;
        while (pending.length > 0 && attempt <= MAX_RETRY_ATTEMPTS) {
            const result = await sendChunk(pending, payload);
            sentCount += result.sentCount;
            invalidTokens.push(...result.invalidTokens);
            transientFailures = result.transientFailures;
            if (transientFailures === 0) {
                break;
            }
            if (attempt === MAX_RETRY_ATTEMPTS) {
                break;
            }
            pending = result.retryTokens;
            attempt += 1;
            await sleep(250 * 2 ** attempt);
        }
    }
    (0, logger_1.logInfo)("FCM multicast completed", {
        type: payload.type,
        tokenCount: deduped.length,
        sentCount,
        invalidTokenCount: invalidTokens.length,
    });
    return {
        sentCount,
        invalidTokens,
        transientFailures,
    };
};
exports.sendMulticastWithRetry = sendMulticastWithRetry;
const trackNotificationAnalytics = async (input) => {
    try {
        await firebase_1.db.collection("notificationAnalytics").doc(input.eventId).set({
            userId: input.userId,
            type: input.type,
            sentCount: input.sentCount,
            invalidTokenCount: input.invalidTokenCount,
            createdAt: firebase_1.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        (0, logger_1.logError)("trackNotificationAnalytics failed", {
            eventId: input.eventId,
            error: error instanceof Error ? error.message : String(error),
        });
        throw error;
    }
};
exports.trackNotificationAnalytics = trackNotificationAnalytics;
//# sourceMappingURL=notificationService.js.map