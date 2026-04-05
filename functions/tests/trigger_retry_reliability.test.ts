import { beforeEach, describe, expect, it, jest } from '@jest/globals';

import {
  reserveNotificationEvent,
  trackNotificationAnalytics,
  updateNotificationEventStatus,
} from '../src/services/notificationService';
import { cleanupInvalidTokens } from '../src/services/tokenService';

jest.mock('../src/utils/firebase', () => ({
  __mocks: {
    createMock: jest.fn(),
    setMock: jest.fn(),
    collectionMock: jest.fn(),
    docMock: jest.fn(),
    batchDeleteMock: jest.fn(),
    batchCommitMock: jest.fn(),
    batchMock: jest.fn(),
  },
  FieldValue: {
    serverTimestamp: () => 'server-timestamp',
  },
  Timestamp: {
    fromDate: (value: Date) => value,
  },
  db: {
    collection: jest.fn((...args: unknown[]) => {
      const moduleRef = jest.requireMock('../src/utils/firebase') as {
        __mocks: {
          collectionMock: jest.Mock;
          docMock: jest.Mock;
          createMock: jest.Mock;
          setMock: jest.Mock;
        };
      };

      const { collectionMock, docMock, createMock, setMock } = moduleRef.__mocks;
      collectionMock(...args);

      return {
        doc: jest.fn((...docArgs: unknown[]) => {
          docMock(...docArgs);
          return {
            create: createMock,
            set: setMock,
          };
        }),
      };
    }),
    batch: jest.fn(() => {
      const moduleRef = jest.requireMock('../src/utils/firebase') as {
        __mocks: {
          batchMock: jest.Mock;
          batchDeleteMock: jest.Mock;
          batchCommitMock: jest.Mock;
        };
      };

      const { batchMock, batchDeleteMock, batchCommitMock } = moduleRef.__mocks;
      batchMock();

      return {
        delete: batchDeleteMock,
        commit: batchCommitMock,
      };
    }),
  },
  messaging: {
    sendEachForMulticast: jest.fn(),
  },
}));

jest.mock('../src/utils/logger', () => ({
  logError: jest.fn(),
  logInfo: jest.fn(),
  logWarn: jest.fn(),
}));

describe('trigger retry reliability guards', () => {
  const firebaseMockModule = jest.requireMock('../src/utils/firebase') as {
    __mocks: {
      createMock: jest.Mock;
      setMock: jest.Mock;
      collectionMock: jest.Mock;
      docMock: jest.Mock;
      batchDeleteMock: jest.Mock;
      batchCommitMock: jest.Mock;
      batchMock: jest.Mock;
    };
  };

  const {
    createMock,
    setMock,
    collectionMock,
    docMock,
    batchDeleteMock,
    batchCommitMock,
    batchMock,
  } = firebaseMockModule.__mocks;

  beforeEach(() => {
    jest.clearAllMocks();
    createMock.mockReset();
    setMock.mockReset();
    collectionMock.mockReset();
    docMock.mockReset();
    batchDeleteMock.mockReset();
    batchCommitMock.mockReset();
    batchMock.mockReset();
  });

  it('returns false for duplicate notification reservation (idempotent)', async () => {
    createMock.mockImplementationOnce(async () => {
      throw new Error('already exists');
    });

    const reserved = await reserveNotificationEvent('evt_1', { type: 'PAYMENT_RECEIVED' });

    expect(reserved).toBe(false);
  });

  it('rethrows unexpected notification reservation errors', async () => {
    createMock.mockImplementationOnce(async () => {
      throw new Error('firestore-write-failed');
    });

    await expect(
      reserveNotificationEvent('evt_2', { type: 'PAYMENT_RECEIVED' }),
    ).rejects.toThrow('firestore-write-failed');
  });

  it('rethrows updateNotificationEventStatus failures for caller retry', async () => {
    setMock.mockImplementationOnce(async () => {
      throw new Error('status-update-failed');
    });

    await expect(
      updateNotificationEventStatus('evt_3', 'failed', { reason: 'test' }),
    ).rejects.toThrow('status-update-failed');
  });

  it('rethrows notification analytics persistence failures', async () => {
    setMock.mockImplementationOnce(async () => {
      throw new Error('analytics-write-failed');
    });

    await expect(
      trackNotificationAnalytics({
        userId: 'u1',
        type: 'RENT_DUE_REMINDER',
        eventId: 'evt_4',
        sentCount: 0,
        invalidTokenCount: 0,
      }),
    ).rejects.toThrow('analytics-write-failed');
  });

  it('rethrows invalid-token cleanup failures so triggers can retry', async () => {
    batchCommitMock.mockImplementationOnce(async () => {
      throw new Error('batch-commit-failed');
    });

    const ref = { id: 'ref_1' } as unknown as { id: string };
    const tokenRefs = new Map<string, { id: string }>([['token_1', ref]]);

    await expect(cleanupInvalidTokens(tokenRefs as unknown as Map<string, never>, ['token_1'])).rejects.toThrow(
      'batch-commit-failed',
    );
    expect(batchDeleteMock).toHaveBeenCalledTimes(1);
  });
});
