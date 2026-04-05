import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue, db } from "../utils/firebase";
import { checkAndIncrementRateLimit } from "../services/rateLimitService";
import {
  reserveNotificationEvent,
  sendMulticastWithRetry,
  trackNotificationAnalytics,
} from "../services/notificationService";
import { cleanupInvalidTokens, getUserDeviceTokens } from "../services/tokenService";
import { validatePaymentForNotification } from "../services/validationService";
import { logError, logInfo, logWarn } from "../utils/logger";

const normalizeStatus = (value: unknown): string => String(value ?? "").trim().toLowerCase();

const inr = (value: number): string =>
  new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value);

export const onPaymentCreated = onDocumentCreated(
  {
    document: "payments/{paymentId}",
    region: "asia-south1",
    maxInstances: 20,
    retry: true,
  },
  async (event) => {
    const paymentId = event.params.paymentId as string;
    const payment = event.data?.data();

    if (!payment) {
      return;
    }

    const status = normalizeStatus(payment.status);
    if (status !== "paid" && status !== "success") {
      logInfo("Skipping payment notification for non-paid status", { paymentId, status });
      return;
    }

    try {
      const validated = await validatePaymentForNotification(payment);
      if (!validated.valid) {
        logWarn("Payment notification skipped after validation", { paymentId });
        return;
      }

      const eventId = `payment_received_${paymentId}`;
      const reserved = await reserveNotificationEvent(eventId, {
        type: "PAYMENT_RECEIVED",
        ownerId: validated.ownerId,
        tenantId: validated.tenantId,
        paymentId,
      });

      if (!reserved) {
        logInfo("Duplicate payment notification prevented", { eventId });
        return;
      }

      const withinRateLimit = await checkAndIncrementRateLimit(validated.ownerId, "PAYMENT_RECEIVED");
      if (!withinRateLimit) {
        logWarn("Payment notification rate-limited", {
          ownerId: validated.ownerId,
          paymentId,
        });
        return;
      }

      const tokenBundle = await getUserDeviceTokens(validated.ownerId);
      if (tokenBundle.tokens.length === 0) {
        logInfo("No owner tokens available for payment notification", {
          ownerId: validated.ownerId,
          paymentId,
        });
        return;
      }

      const title = "Payment Received";
      const body = `Rs ${inr(validated.amount)} received from ${validated.tenantName}`;
      const payload = {
        type: "PAYMENT_RECEIVED" as const,
        title,
        body,
        data: {
          type: "PAYMENT_RECEIVED",
          tenantId: validated.tenantId,
          paymentId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      const dispatch = await sendMulticastWithRetry(tokenBundle.tokens, payload);
      await cleanupInvalidTokens(tokenBundle.tokenRefs, dispatch.invalidTokens);

      await Promise.all([
        db.collection("messages").doc(eventId).set({
          type: "PAYMENT_RECEIVED",
          ownerId: validated.ownerId,
          tenantId: validated.tenantId,
          paymentId,
          title,
          body,
          read: false,
          severity: "info",
          createdAt: FieldValue.serverTimestamp(),
        }),
        trackNotificationAnalytics({
          userId: validated.ownerId,
          type: "PAYMENT_RECEIVED",
          eventId,
          sentCount: dispatch.sentCount,
          invalidTokenCount: dispatch.invalidTokens.length,
        }),
      ]);

      logInfo("Payment notification dispatched", {
        paymentId,
        ownerId: validated.ownerId,
        sentCount: dispatch.sentCount,
      });
    } catch (error) {
      logError("onPaymentCreated failed", {
        paymentId,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  },
);
