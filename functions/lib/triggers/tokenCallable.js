"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.unregisterDeviceToken = exports.registerDeviceToken = void 0;
const https_1 = require("firebase-functions/v2/https");
const tokenService_1 = require("../services/tokenService");
const logger_1 = require("../utils/logger");
const normalizePlatform = (value) => String(value ?? "unknown").trim().toLowerCase();
exports.registerDeviceToken = (0, https_1.onCall)({
    region: "asia-south1",
    enforceAppCheck: true,
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const token = String(request.data?.token ?? "").trim();
    const platform = normalizePlatform(request.data?.platform);
    if (!token) {
        throw new https_1.HttpsError("invalid-argument", "token is required");
    }
    try {
        await (0, tokenService_1.upsertDeviceToken)(uid, token, platform);
        return { ok: true };
    }
    catch (error) {
        (0, logger_1.logError)("registerDeviceToken failed", {
            uid,
            error: error instanceof Error ? error.message : String(error),
        });
        throw new https_1.HttpsError("internal", "Could not register token");
    }
});
exports.unregisterDeviceToken = (0, https_1.onCall)({
    region: "asia-south1",
    enforceAppCheck: true,
}, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const token = String(request.data?.token ?? "").trim();
    if (!token) {
        throw new https_1.HttpsError("invalid-argument", "token is required");
    }
    try {
        await (0, tokenService_1.removeDeviceToken)(uid, token);
        return { ok: true };
    }
    catch (error) {
        (0, logger_1.logError)("unregisterDeviceToken failed", {
            uid,
            error: error instanceof Error ? error.message : String(error),
        });
        throw new https_1.HttpsError("internal", "Could not unregister token");
    }
});
//# sourceMappingURL=tokenCallable.js.map