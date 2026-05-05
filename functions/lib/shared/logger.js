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
exports.AppLogger = void 0;
const logger = __importStar(require("firebase-functions/logger"));
/**
 * Environment-aware structured logging utility.
 * Ensures no sensitive data is leaked and logs are formatted for Google Cloud Logging.
 */
class AppLogger {
    static debug(message, data) {
        logger.debug(message, this.sanitize(data));
    }
    static info(message, data) {
        logger.info(message, this.sanitize(data));
    }
    static warn(message, data) {
        logger.warn(message, this.sanitize(data));
    }
    static error(message, error, context) {
        logger.error(message, {
            ...this.sanitize(context),
            error: error instanceof Error ? {
                message: error.message,
                stack: error.stack,
            } : error,
        });
    }
    /**
     * Remove sensitive fields like tokens, secrets, or full payment payloads from logs.
     */
    static sanitize(data) {
        if (!data)
            return undefined;
        const sensitiveKeys = ["token", "fcmToken", "secret", "password", "razorpay_secret", "signature"];
        const sanitized = JSON.parse(JSON.stringify(data));
        const walk = (obj) => {
            if (!obj || typeof obj !== "object")
                return;
            for (const key in obj) {
                if (sensitiveKeys.some(s => key.toLowerCase().includes(s))) {
                    obj[key] = "[REDACTED]";
                }
                else if (typeof obj[key] === "object") {
                    walk(obj[key]);
                }
            }
        };
        walk(sanitized);
        return sanitized;
    }
}
exports.AppLogger = AppLogger;
//# sourceMappingURL=logger.js.map