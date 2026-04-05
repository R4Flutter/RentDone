import firebaseFunctionsTest from 'firebase-functions-test';
import { afterAll, describe, expect, it } from '@jest/globals';

import {
  createPaymentIntent,
  quoteOwnerRazorpayPayment,
  quotePayment,
} from '../src/triggers/paymentCallable';

type HttpsLikeError = {
  code?: string;
  message?: string;
};

const testEnv = firebaseFunctionsTest();

const wrapCallable = (fn: unknown) => testEnv.wrap(fn as never) as (data: unknown, ctx?: unknown) => Promise<unknown>;

const expectHttpsCode = async (promise: Promise<unknown>, code: string): Promise<void> => {
  await expect(promise).rejects.toMatchObject({ code } satisfies HttpsLikeError);
};

describe('payment callable security and quote behavior', () => {
  afterAll(() => {
    testEnv.cleanup();
  });

  it('rejects unauthenticated quoteOwnerRazorpayPayment request', async () => {
    const wrapped = wrapCallable(quoteOwnerRazorpayPayment);
    await expectHttpsCode(wrapped({ data: { amount: 500 } }), 'unauthenticated');
  });

  it('rejects incorrect payment amount for quoteOwnerRazorpayPayment', async () => {
    const wrapped = wrapCallable(quoteOwnerRazorpayPayment);
    await expectHttpsCode(
      wrapped({ data: { amount: 0 }, auth: { uid: 'owner_1' } }),
      'invalid-argument',
    );
  });

  it('accepts correct payment amount for quoteOwnerRazorpayPayment', async () => {
    const wrapped = wrapCallable(quoteOwnerRazorpayPayment);
    const response = (await wrapped({
      data: { amount: 1000 },
      auth: { uid: 'owner_1' },
    })) as Record<string, number | string>;

    expect(response.currency).toBe('INR');
    expect(response.rentAmountInPaise).toBe(100000);
    expect((response.totalPayableInPaise as number) > (response.rentAmountInPaise as number)).toBe(true);
  });

  it('rejects unauthenticated createPaymentIntent request', async () => {
    const wrapped = wrapCallable(createPaymentIntent);
    await expectHttpsCode(
      wrapped({
        data: {
          leaseId: 'lease_1',
          month: 1,
          year: 2026,
        },
      }),
      'unauthenticated',
    );
  });

  it('rejects unauthenticated quotePayment request', async () => {
    const wrapped = wrapCallable(quotePayment);
    await expectHttpsCode(
      wrapped({
        data: {
          leaseId: 'lease_1',
          month: 1,
          year: 2026,
        },
      }),
      'unauthenticated',
    );
  });

  it('rejects out-of-range payment amount for quoteOwnerRazorpayPayment', async () => {
    const wrapped = wrapCallable(quoteOwnerRazorpayPayment);
    await expectHttpsCode(
      wrapped({ data: { amount: 5000001 }, auth: { uid: 'owner_1' } }),
      'invalid-argument',
    );
  });
});
