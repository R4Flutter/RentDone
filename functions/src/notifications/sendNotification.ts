import * as admin from "firebase-admin";
import { AppLogger } from "../shared/logger";

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Sends a push notification to multiple device tokens.
 * Handles automatic invalid token detection for cleanup.
 */
export async function sendMulticastNotification(
  tokens: string[],
  payload: NotificationPayload
): Promise<{ sentCount: number; invalidTokens: string[] }> {
  const uniqueTokens = Array.from(new Set(tokens.filter(Boolean)));
  if (uniqueTokens.length === 0) return { sentCount: 0, invalidTokens: [] };

  const invalidTokens: string[] = [];
  let sentCount = 0;

  // FCM multicast limits to 500 tokens per call
  for (let i = 0; i < uniqueTokens.length; i += 500) {
    const chunk = uniqueTokens.slice(i, i + 500);
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        android: { priority: "high" },
        apns: {
          payload: {
            aps: { sound: "default" },
          },
        },
      });

      sentCount += response.successCount;
      response.responses.forEach((res, idx) => {
        if (!res.success && res.error) {
          const code = res.error.code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            invalidTokens.push(chunk[idx]);
          }
        }
      });
    } catch (error) {
      AppLogger.error("Multicast notification chunk failed", error);
    }
  }

  return { sentCount, invalidTokens };
}

/**
 * Records a notification in the 'messages' collection for in-app history.
 */
export async function recordInAppMessage(params: {
  id: string;
  ownerId?: string;
  tenantId?: string;
  tenantUserId?: string;
  title: string;
  body: string;
  type: string;
  severity: "info" | "warning" | "error";
}) {
  const db = admin.firestore();
  await db.collection("messages").doc(params.id).set({
    ...params,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
