/**
 * Unified Backend Entry Point
 * Production-ready exports for RentDone Cloud Functions v2
 */

// Payments
export { createRazorpayOrder } from "./payments/createOrder";

// Tenants
export { linkTenantAccount } from "./tenants/linkTenantAccount";

// Notifications & Cleanup
export { cleanupExpiredSystemLogs } from "./notifications/tokenCleanup";

// Schedulers
export { sendRentDueReminders } from "./schedulers/rentReminder";

// Triggers from existing V2 files (validated during audit)
export { onPaymentCreated } from "./triggers/paymentTrigger";
export { registerDeviceToken, unregisterDeviceToken } from "./triggers/tokenCallable";
export { createPayment, verifyPayment, updatePaymentStatus } from "./triggers/paymentCallable";
