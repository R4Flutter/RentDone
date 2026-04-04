import { FieldValue, Timestamp, db, messaging } from "../utils/firebase";
import { NotificationDispatchResult, PushPayload } from "../types/domain";
import { logError, logInfo, logWarn } from "../utils/logger";

const FCM_BATCH_SIZE = 500;
const MAX_RETRY_ATTEMPTS = 2;

const isInvalidTokenError = (code: string): boolean =>
  code.includes("registration-token-not-registered") ||
  code.includes("invalid-registration-token") ||
  code.includes("mismatch-credential");

const isTransientError = (code: string): boolean =>
  code.includes("internal") ||
  code.includes("unavailable") ||
  code.includes("deadline-exceeded") ||
  code.includes("resource-exhausted") ||
  code.includes("unknown");

const sleep = async (ms: number): Promise<void> =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export const reserveNotificationEvent = async (
  eventKey: string,
  payload: Record<string, unknown>,
): Promise<boolean> => {
  const ref = db.collection("_notificationEvents").doc(eventKey);
  try {
    await ref.create({
      ...payload,
      status: "reserved",
      reservedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
    });
    return true;
  } catch (error) {
    const errorText = error instanceof Error ? error.message.toLowerCase() : String(error).toLowerCase();
    if (errorText.includes("already exists")) {
      return false;
    }
    throw error;
  }
};

export const updateNotificationEventStatus = async (
  eventKey: string,
  status: "sent" | "failed",
  payload?: Record<string, unknown>,
): Promise<void> => {
  try {
    await db.collection("_notificationEvents").doc(eventKey).set(
      {
        status,
        ...(status === "sent"
          ? { sentAt: FieldValue.serverTimestamp() }
          : { failedAt: FieldValue.serverTimestamp() }),
        ...(payload ?? {}),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (error) {
    logError("updateNotificationEventStatus failed", {
      eventKey,
      status,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

const sendChunk = async (
  tokens: string[],
  payload: PushPayload,
): Promise<NotificationDispatchResult & { retryTokens: string[] }> => {
  const invalidTokens: string[] = [];
  const retryTokens: string[] = [];
  let sentCount = 0;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data,
    android: {
      priority: "high",
      notification: {
        channelId: "rentdone_high_priority",
        sound: "default",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  sentCount += response.successCount;

  response.responses.forEach((entry, index) => {
    if (entry.success) {
      return;
    }
    const code = String(entry.error?.code ?? "").toLowerCase();
    if (isInvalidTokenError(code)) {
      invalidTokens.push(tokens[index]);
      return;
    }
    if (isTransientError(code)) {
      retryTokens.push(tokens[index]);
      return;
    }

    logWarn("Non-retryable FCM error", {
      code,
      message: entry.error?.message,
      type: payload.type,
    });
  });

  return {
    sentCount,
    invalidTokens,
    transientFailures: retryTokens.length,
    retryTokens,
  };
};

export const sendMulticastWithRetry = async (
  tokens: string[],
  payload: PushPayload,
): Promise<NotificationDispatchResult> => {
  const deduped = [...new Set(tokens.filter((token) => token.trim().length > 0))];
  if (deduped.length === 0) {
    return { sentCount: 0, invalidTokens: [], transientFailures: 0 };
  }

  const invalidTokens: string[] = [];
  let sentCount = 0;
  let transientFailures = 0;

  for (let index = 0; index < deduped.length; index += FCM_BATCH_SIZE) {
    const chunk = deduped.slice(index, index + FCM_BATCH_SIZE);

    let pending = [...chunk];
    let attempt = 0;

    while (pending.length > 0 && attempt <= MAX_RETRY_ATTEMPTS) {
      const result = await sendChunk(pending, payload);
      sentCount += result.sentCount;
      invalidTokens.push(...result.invalidTokens);

      transientFailures = result.transientFailures;
      if (transientFailures === 0) {
        break;
      }

      if (attempt === MAX_RETRY_ATTEMPTS) {
        break;
      }

      pending = result.retryTokens;
      attempt += 1;
      await sleep(250 * 2 ** attempt);
    }
  }

  logInfo("FCM multicast completed", {
    type: payload.type,
    tokenCount: deduped.length,
    sentCount,
    invalidTokenCount: invalidTokens.length,
  });

  return {
    sentCount,
    invalidTokens,
    transientFailures,
  };
};

export const trackNotificationAnalytics = async (input: {
  userId: string;
  type: string;
  eventId: string;
  sentCount: number;
  invalidTokenCount: number;
}): Promise<void> => {
  try {
    await db.collection("notificationAnalytics").doc(input.eventId).set({
      userId: input.userId,
      type: input.type,
      sentCount: input.sentCount,
      invalidTokenCount: input.invalidTokenCount,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logError("trackNotificationAnalytics failed", {
      eventId: input.eventId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};
