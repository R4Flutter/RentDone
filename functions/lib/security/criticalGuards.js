"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.canReadPublicProfile = exports.canAccessOwnUserDoc = exports.resolveAuthUid = exports.isPaymentAmountValid = exports.MAX_PAYMENT_AMOUNT = exports.MIN_PAYMENT_AMOUNT = void 0;
exports.MIN_PAYMENT_AMOUNT = 1;
exports.MAX_PAYMENT_AMOUNT = 5_000_000;
const isPaymentAmountValid = (amount, min = exports.MIN_PAYMENT_AMOUNT, max = exports.MAX_PAYMENT_AMOUNT) => Number.isInteger(amount) && amount >= min && amount <= max;
exports.isPaymentAmountValid = isPaymentAmountValid;
const resolveAuthUid = (uid) => {
    const normalized = String(uid ?? '').trim();
    if (!normalized) {
        throw new Error('unauthenticated');
    }
    return normalized;
};
exports.resolveAuthUid = resolveAuthUid;
const canAccessOwnUserDoc = (authUid, targetUserId) => {
    const actor = String(authUid ?? '').trim();
    const target = String(targetUserId ?? '').trim();
    return actor.length > 0 && actor === target;
};
exports.canAccessOwnUserDoc = canAccessOwnUserDoc;
const canReadPublicProfile = (isAuthenticated) => isAuthenticated === true;
exports.canReadPublicProfile = canReadPublicProfile;
//# sourceMappingURL=criticalGuards.js.map