import { describe, expect, it } from '@jest/globals';

import {
  MAX_PAYMENT_AMOUNT,
  MIN_PAYMENT_AMOUNT,
  canAccessOwnUserDoc,
  canReadPublicProfile,
  isPaymentAmountValid,
  resolveAuthUid,
} from '../src/security/criticalGuards';

describe('critical security guards', () => {
  it('rejects incorrect payment amount', () => {
    expect(isPaymentAmountValid(0)).toBe(false);
    expect(isPaymentAmountValid(MAX_PAYMENT_AMOUNT + 1)).toBe(false);
  });

  it('accepts correct payment amount', () => {
    expect(isPaymentAmountValid(MIN_PAYMENT_AMOUNT)).toBe(true);
    expect(isPaymentAmountValid(1200)).toBe(true);
  });

  it('rejects unauthenticated users in auth resolver', () => {
    expect(() => resolveAuthUid('')).toThrow('unauthenticated');
    expect(() => resolveAuthUid(null)).toThrow('unauthenticated');
  });

  it('allows valid authenticated users in auth resolver', () => {
    expect(resolveAuthUid('tenant_1')).toBe('tenant_1');
  });

  it('enforces private users document ownership', () => {
    expect(canAccessOwnUserDoc('u1', 'u1')).toBe(true);
    expect(canAccessOwnUserDoc('u1', 'u2')).toBe(false);
  });

  it('allows only authenticated reads for public profiles', () => {
    expect(canReadPublicProfile(true)).toBe(true);
    expect(canReadPublicProfile(false)).toBe(false);
  });
});
