import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, db } from "../utils/firebase";
import { checkAndIncrementRateLimit } from "../services/rateLimitService";
import {
  reserveNotificationEvent,
  sendMulticastWithRetry,
  trackNotificationAnalytics,
} from "../services/notificationService";
import { cleanupInvalidTokens, getUserDeviceTokens } from "../services/tokenService";
import { logError, logInfo, logWarn } from "../utils/logger";

const toIstNow = (): Date => new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));

const dueDateKey = (date: Date): string => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
};

const statusString = (value: unknown): string => String(value ?? "").trim().toLowerCase();

const buildRentDueBody = (amount: number): string => {
  const value = Number.isFinite(amount) ? amount : 0;
  return `Your due date is close. Please pay Rs ${new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value)} to your owner.`;
};

const getTenantUserId = (tenant: FirebaseFirestore.DocumentData, tenantDocId: string): string => {
  const authUid = String(tenant.authUid ?? "").trim();
  if (authUid) {
    return authUid;
  }
  return tenantDocId;
};

const loadDueTenants = async (today: Date): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> => {
  const day = today.getDate();
  const start = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0, 0);
  const end = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 23, 59, 59, 999);

  const [dueDaySnap, dueDateSnap] = await Promise.all([
    db.collection("tenants").where("status", "==", "active").where("rentDueDay", "==", day).get(),
    db.collection("tenants").where("status", "==", "active").where("dueDate", ">=", start).where("dueDate", "<=", end).get(),
  ]);

  const deduped = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  dueDaySnap.docs.forEach((doc) => deduped.set(doc.id, doc));
  dueDateSnap.docs.forEach((doc) => deduped.set(doc.id, doc));
  return [...deduped.values()];
};

export const sendRentDueReminders = onSchedule(
  {
    schedule: "0 9 * * *",
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
    retryCount: 2,
    maxRetrySeconds: 300,
  },
  async () => {
    const today = toIstNow();
    const dateKey = dueDateKey(today);

    try {
      const dueTenantDocs = await loadDueTenants(today);
      if (dueTenantDocs.length === 0) {
        logInfo("No tenants due today", { dateKey });
        return;
      }

      let sentCount = 0;
      let processed = 0;

      logInfo("Processing rent reminders in batches", { total: dueTenantDocs.length, batchSize: 50 });

      // Process in chunks of 50 to improve scalability
      const chunkSize = 50;
      for (let i = 0; i < dueTenantDocs.length; i += chunkSize) {
        const chunk = dueTenantDocs.slice(i, i + chunkSize);
        
        await Promise.all(chunk.map(async (tenantDoc) => {
          const tenant = tenantDoc.data();
          const tenantUserId = getTenantUserId(tenant, tenantDoc.id);
          const ownerId = String(tenant.ownerId ?? "").trim();
          const tenantStatus = statusString(tenant.status);

          if (!tenantUserId || !ownerId || (tenantStatus && tenantStatus !== "active")) {
            return;
          }

          const eventId = `rent_due_${tenantDoc.id}_${dateKey}`;
          const reserved = await reserveNotificationEvent(eventId, {
            type: "RENT_DUE_REMINDER",
            tenantId: tenantDoc.id,
            tenantUserId,
            ownerId,
            dateKey,
          });

          if (!reserved) {
            return;
          }

          const withinRateLimit = await checkAndIncrementRateLimit(tenantUserId, "RENT_DUE_REMINDER");
          if (!withinRateLimit) {
            logWarn("Tenant rent reminder rate-limited", { tenantUserId, eventId });
            return;
          }

          const tokenBundle = await getUserDeviceTokens(tenantUserId);
          if (tokenBundle.tokens.length === 0) {
            return;
          }

          const amount = Number(tenant.rentAmount ?? tenant.monthlyRent ?? 0);
          const payload = {
            type: "RENT_DUE_REMINDER" as const,
            title: "Rent Due Reminder",
            body: buildRentDueBody(amount),
            data: {
              type: "RENT_DUE_REMINDER",
              tenantId: tenantDoc.id,
              ownerId,
              targetRole: "tenant",
              action: "pay_now",
              actionLabel: "Pay",
              actionRoute: "/tenant/payments",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          };

          const dispatch = await sendMulticastWithRetry(tokenBundle.tokens, payload);
          await cleanupInvalidTokens(tokenBundle.tokenRefs, dispatch.invalidTokens);

          await Promise.all([
            db.collection("messages").doc(eventId).set({
              type: "RENT_DUE_REMINDER",
              title: payload.title,
              body: payload.body,
              ownerId,
              tenantId: tenantDoc.id,
              read: false,
              severity: "warning",
              createdAt: FieldValue.serverTimestamp(),
            }),
            trackNotificationAnalytics({
              userId: tenantUserId,
              type: "RENT_DUE_REMINDER",
              eventId,
              sentCount: dispatch.sentCount,
              invalidTokenCount: dispatch.invalidTokens.length,
            }),
          ]);

          sentCount += dispatch.sentCount;
          processed += 1;
        }));
      }

      logInfo("sendRentDueReminders completed", {
        dateKey,
        processed,
        sentCount,
      });
    } catch (error) {
      logError("sendRentDueReminders failed", {
        dateKey,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);
