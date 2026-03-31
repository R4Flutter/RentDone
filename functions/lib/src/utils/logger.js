"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logError = exports.logWarn = exports.logInfo = void 0;
const firebase_functions_1 = require("firebase-functions");
const logInfo = (message, data = {}) => {
    firebase_functions_1.logger.info(message, data);
};
exports.logInfo = logInfo;
const logWarn = (message, data = {}) => {
    firebase_functions_1.logger.warn(message, data);
};
exports.logWarn = logWarn;
const logError = (message, data = {}) => {
    firebase_functions_1.logger.error(message, data);
};
exports.logError = logError;
//# sourceMappingURL=logger.js.map