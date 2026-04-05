"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.touchDeviceTokenUsage = exports.cleanupInvalidTokens = exports.getUserDeviceTokens = exports.removeDeviceToken = exports.upsertDeviceToken = void 0;
const node_crypto_1 = require("node:crypto");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../utils/logger");
const DEVICE_TOKEN_SUBCOLLECTION = "deviceTokens";
const normalizeToken = (token) => token.trim();
const tokenDocId = (token) => (0, node_crypto_1.createHash)("sha256").update(token).digest("hex");
const sanitizePlatform = (platform) => {
    const value = platform.trim().toLowerCase();
    if (value === "android" || value === "ios" || value === "web") {
        return value;
    }
    return "unknown";
};
const upsertDeviceToken = async (userId, rawToken, rawPlatform) => {
    const token = normalizeToken(rawToken);
    if (!token) {
        throw new Error("Token must not be empty");
    }
    const platform = sanitizePlatform(rawPlatform);
    const now = firebase_1.FieldValue.serverTimestamp();
    const id = tokenDocId(token);
    const tokenRef = firebase_1.db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).doc(id);
    await firebase_1.db.runTransaction(async (txn) => {
        const current = await txn.get(tokenRef);
        txn.set(tokenRef, {
            token,
            platform,
            createdAt: current.exists ? current.get("createdAt") ?? now : now,
            lastUsedAt: now,
        }, { merge: true });
    });
};
exports.upsertDeviceToken = upsertDeviceToken;
const removeDeviceToken = async (userId, rawToken) => {
    const token = normalizeToken(rawToken);
    if (!token) {
        return;
    }
    const id = tokenDocId(token);
    await firebase_1.db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).doc(id).delete();
};
exports.removeDeviceToken = removeDeviceToken;
const getUserDeviceTokens = async (userId) => {
    const tokenSnap = await firebase_1.db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).get();
    const tokenRefs = new Map();
    const uniqueTokens = new Set();
    tokenSnap.forEach((doc) => {
        const token = String(doc.get("token") ?? "").trim();
        if (!token) {
            return;
        }
        uniqueTokens.add(token);
        tokenRefs.set(token, doc.ref);
    });
    return {
        tokens: [...uniqueTokens],
        tokenRefs,
    };
};
exports.getUserDeviceTokens = getUserDeviceTokens;
const cleanupInvalidTokens = async (tokenRefs, invalidTokens) => {
    if (invalidTokens.length === 0) {
        return;
    }
    const batch = firebase_1.db.batch();
    let deleted = 0;
    for (const token of invalidTokens) {
        const ref = tokenRefs.get(token);
        if (!ref) {
            continue;
        }
        batch.delete(ref);
        deleted += 1;
    }
    if (deleted === 0) {
        return;
    }
    try {
        await batch.commit();
    }
    catch (error) {
        (0, logger_1.logError)("cleanupInvalidTokens failed", {
            deleted,
            error: error instanceof Error ? error.message : String(error),
        });
        throw error;
    }
};
exports.cleanupInvalidTokens = cleanupInvalidTokens;
const touchDeviceTokenUsage = async (userId, rawToken) => {
    const token = normalizeToken(rawToken);
    if (!token) {
        return;
    }
    const id = tokenDocId(token);
    const ref = firebase_1.db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).doc(id);
    try {
        await ref.set({ lastUsedAt: firebase_1.FieldValue.serverTimestamp() }, { merge: true });
    }
    catch (error) {
        (0, logger_1.logWarn)("touchDeviceTokenUsage failed", {
            userId,
            tokenId: id,
            error: error instanceof Error ? error.message : String(error),
        });
        throw error;
    }
};
exports.touchDeviceTokenUsage = touchDeviceTokenUsage;
//# sourceMappingURL=tokenService.js.map