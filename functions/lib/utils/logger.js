"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logError = exports.logWarn = exports.logInfo = void 0;
const firebase_functions_1 = require("firebase-functions");
const logger_1 = require("../shared/logger");
const logInfo = (message, data = {}) => {
    firebase_functions_1.logger.info(message, logger_1.AppLogger.sanitize(data));
};
exports.logInfo = logInfo;
const logWarn = (message, data = {}) => {
    firebase_functions_1.logger.warn(message, logger_1.AppLogger.sanitize(data));
};
exports.logWarn = logWarn;
const logError = (message, data = {}) => {
    firebase_functions_1.logger.error(message, logger_1.AppLogger.sanitize(data));
};
exports.logError = logError;
//# sourceMappingURL=logger.js.map