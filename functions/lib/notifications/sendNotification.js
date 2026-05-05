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
exports.sendMulticastNotification = sendMulticastNotification;
exports.recordInAppMessage = recordInAppMessage;
const admin = __importStar(require("firebase-admin"));
const logger_1 = require("../shared/logger");
/**
 * Sends a push notification to multiple device tokens.
 * Handles automatic invalid token detection for cleanup.
 */
async function sendMulticastNotification(tokens, payload) {
    const uniqueTokens = Array.from(new Set(tokens.filter(Boolean)));
    if (uniqueTokens.length === 0)
        return { sentCount: 0, invalidTokens: [] };
    const invalidTokens = [];
    let sentCount = 0;
    // FCM multicast limits to 500 tokens per call
    for (let i = 0; i < uniqueTokens.length; i += 500) {
        const chunk = uniqueTokens.slice(i, i + 500);
        try {
            const response = await admin.messaging().sendEachForMulticast({
                tokens: chunk,
                notification: {
                    title: payload.title,
                    body: payload.body,
                },
                data: payload.data,
                android: { priority: "high" },
                apns: {
                    payload: {
                        aps: { sound: "default" },
                    },
                },
            });
            sentCount += response.successCount;
            response.responses.forEach((res, idx) => {
                if (!res.success && res.error) {
                    const code = res.error.code;
                    if (code === "messaging/registration-token-not-registered" ||
                        code === "messaging/invalid-registration-token") {
                        invalidTokens.push(chunk[idx]);
                    }
                }
            });
        }
        catch (error) {
            logger_1.AppLogger.error("Multicast notification chunk failed", error);
        }
    }
    return { sentCount, invalidTokens };
}
/**
 * Records a notification in the 'messages' collection for in-app history.
 */
async function recordInAppMessage(params) {
    const db = admin.firestore();
    await db.collection("messages").doc(params.id).set({
        ...params,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
//# sourceMappingURL=sendNotification.js.map