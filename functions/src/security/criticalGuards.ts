export const MIN_PAYMENT_AMOUNT = 1;
export const MAX_PAYMENT_AMOUNT = 5_000_000;

export const isPaymentAmountValid = (
  amount: number,
  min = MIN_PAYMENT_AMOUNT,
  max = MAX_PAYMENT_AMOUNT,
): boolean => Number.isInteger(amount) && amount >= min && amount <= max;

export const resolveAuthUid = (uid: unknown): string => {
  const normalized = String(uid ?? '').trim();
  if (!normalized) {
    throw new Error('unauthenticated');
  }
  return normalized;
};

export const canAccessOwnUserDoc = (
  authUid: unknown,
  targetUserId: unknown,
): boolean => {
  const actor = String(authUid ?? '').trim();
  const target = String(targetUserId ?? '').trim();
  return actor.length > 0 && actor === target;
};

export const canReadPublicProfile = (isAuthenticated: boolean): boolean =>
  isAuthenticated === true;
