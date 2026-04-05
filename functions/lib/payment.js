"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.razorpayPaymentWebhook = exports.activateOwnerFreeSubscription = exports.getOwnerSubscriptionSnapshot = exports.ensureOwnerSubscriptionProfile = exports.verifyTenantSubscriptionPayment = exports.createTenantSubscriptionPaymentIntent = exports.verifyOwnerSubscriptionPayment = exports.createOwnerSubscriptionPaymentIntent = exports.confirmRazorpayPayment = exports.quotePayment = exports.createPaymentIntent = exports.verifyOwnerRazorpayPayment = exports.createOwnerRazorpayPaymentIntent = exports.quoteOwnerRazorpayPayment = exports.updatePaymentStatus = exports.verifyPayment = exports.createPayment = void 0;
// Payment module entrypoint to keep exports modular and discoverable.
var paymentCallable_1 = require("./triggers/paymentCallable");
Object.defineProperty(exports, "createPayment", { enumerable: true, get: function () { return paymentCallable_1.createPayment; } });
Object.defineProperty(exports, "verifyPayment", { enumerable: true, get: function () { return paymentCallable_1.verifyPayment; } });
Object.defineProperty(exports, "updatePaymentStatus", { enumerable: true, get: function () { return paymentCallable_1.updatePaymentStatus; } });
Object.defineProperty(exports, "quoteOwnerRazorpayPayment", { enumerable: true, get: function () { return paymentCallable_1.quoteOwnerRazorpayPayment; } });
Object.defineProperty(exports, "createOwnerRazorpayPaymentIntent", { enumerable: true, get: function () { return paymentCallable_1.createOwnerRazorpayPaymentIntent; } });
Object.defineProperty(exports, "verifyOwnerRazorpayPayment", { enumerable: true, get: function () { return paymentCallable_1.verifyOwnerRazorpayPayment; } });
Object.defineProperty(exports, "createPaymentIntent", { enumerable: true, get: function () { return paymentCallable_1.createPaymentIntent; } });
Object.defineProperty(exports, "quotePayment", { enumerable: true, get: function () { return paymentCallable_1.quotePayment; } });
Object.defineProperty(exports, "confirmRazorpayPayment", { enumerable: true, get: function () { return paymentCallable_1.confirmRazorpayPayment; } });
Object.defineProperty(exports, "createOwnerSubscriptionPaymentIntent", { enumerable: true, get: function () { return paymentCallable_1.createOwnerSubscriptionPaymentIntent; } });
Object.defineProperty(exports, "verifyOwnerSubscriptionPayment", { enumerable: true, get: function () { return paymentCallable_1.verifyOwnerSubscriptionPayment; } });
Object.defineProperty(exports, "createTenantSubscriptionPaymentIntent", { enumerable: true, get: function () { return paymentCallable_1.createTenantSubscriptionPaymentIntent; } });
Object.defineProperty(exports, "verifyTenantSubscriptionPayment", { enumerable: true, get: function () { return paymentCallable_1.verifyTenantSubscriptionPayment; } });
Object.defineProperty(exports, "ensureOwnerSubscriptionProfile", { enumerable: true, get: function () { return paymentCallable_1.ensureOwnerSubscriptionProfile; } });
Object.defineProperty(exports, "getOwnerSubscriptionSnapshot", { enumerable: true, get: function () { return paymentCallable_1.getOwnerSubscriptionSnapshot; } });
Object.defineProperty(exports, "activateOwnerFreeSubscription", { enumerable: true, get: function () { return paymentCallable_1.activateOwnerFreeSubscription; } });
Object.defineProperty(exports, "razorpayPaymentWebhook", { enumerable: true, get: function () { return paymentCallable_1.razorpayPaymentWebhook; } });
//# sourceMappingURL=payment.js.map