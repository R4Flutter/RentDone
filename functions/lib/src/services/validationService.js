"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validatePaymentForNotification = void 0;
const firebase_1 = require("../utils/firebase");
const safeString = (value) => String(value ?? "").trim();
const validatePaymentForNotification = async (payment) => {
    const ownerId = safeString(payment.ownerId);
    const tenantId = safeString(payment.tenantId);
    const amount = Number(payment.amount ?? payment.paidAmount ?? 0);
    if (!ownerId || !tenantId || !Number.isFinite(amount) || amount <= 0) {
        return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
    }
    const [ownerDoc, tenantDoc] = await Promise.all([
        firebase_1.db.collection("users").doc(ownerId).get(),
        firebase_1.db.collection("tenants").doc(tenantId).get(),
    ]);
    if (!ownerDoc.exists || !tenantDoc.exists) {
        return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
    }
    const ownerRole = safeString(ownerDoc.get("role")).toLowerCase();
    if (ownerRole !== "owner") {
        return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
    }
    const tenantOwnerId = safeString(tenantDoc.get("ownerId"));
    if (tenantOwnerId !== ownerId) {
        return { ownerId, tenantId, amount, tenantName: "Tenant", valid: false };
    }
    const tenantName = safeString(tenantDoc.get("fullName") ?? tenantDoc.get("name")) || "Tenant";
    return {
        ownerId,
        tenantId,
        amount,
        tenantName,
        valid: true,
    };
};
exports.validatePaymentForNotification = validatePaymentForNotification;
//# sourceMappingURL=validationService.js.map