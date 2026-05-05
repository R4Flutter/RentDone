"use strict";
/**
 * Unified Backend Entry Point
 * Production-ready exports for RentDone Cloud Functions v2
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.updatePaymentStatus = exports.verifyPayment = exports.createPayment = exports.unregisterDeviceToken = exports.registerDeviceToken = exports.onPaymentCreated = exports.sendRentDueReminders = exports.cleanupExpiredSystemLogs = exports.linkTenantAccount = exports.createRazorpayOrder = void 0;
// Payments
var createOrder_1 = require("./payments/createOrder");
Object.defineProperty(exports, "createRazorpayOrder", { enumerable: true, get: function () { return createOrder_1.createRazorpayOrder; } });
// Tenants
var linkTenantAccount_1 = require("./tenants/linkTenantAccount");
Object.defineProperty(exports, "linkTenantAccount", { enumerable: true, get: function () { return linkTenantAccount_1.linkTenantAccount; } });
// Notifications & Cleanup
var tokenCleanup_1 = require("./notifications/tokenCleanup");
Object.defineProperty(exports, "cleanupExpiredSystemLogs", { enumerable: true, get: function () { return tokenCleanup_1.cleanupExpiredSystemLogs; } });
// Schedulers
var rentReminder_1 = require("./schedulers/rentReminder");
Object.defineProperty(exports, "sendRentDueReminders", { enumerable: true, get: function () { return rentReminder_1.sendRentDueReminders; } });
// Triggers from existing V2 files (validated during audit)
var paymentTrigger_1 = require("./triggers/paymentTrigger");
Object.defineProperty(exports, "onPaymentCreated", { enumerable: true, get: function () { return paymentTrigger_1.onPaymentCreated; } });
var tokenCallable_1 = require("./triggers/tokenCallable");
Object.defineProperty(exports, "registerDeviceToken", { enumerable: true, get: function () { return tokenCallable_1.registerDeviceToken; } });
Object.defineProperty(exports, "unregisterDeviceToken", { enumerable: true, get: function () { return tokenCallable_1.unregisterDeviceToken; } });
var paymentCallable_1 = require("./triggers/paymentCallable");
Object.defineProperty(exports, "createPayment", { enumerable: true, get: function () { return paymentCallable_1.createPayment; } });
Object.defineProperty(exports, "verifyPayment", { enumerable: true, get: function () { return paymentCallable_1.verifyPayment; } });
Object.defineProperty(exports, "updatePaymentStatus", { enumerable: true, get: function () { return paymentCallable_1.updatePaymentStatus; } });
//# sourceMappingURL=index.js.map