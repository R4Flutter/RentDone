import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../utils/firebase";
import { AppLogger } from "../shared/logger";
import { sendMulticastNotification, recordInAppMessage } from "../notifications/sendNotification";
import { Tenant } from "../shared/types";

/**
 * Daily scheduler to remind tenants about upcoming rent due dates.
 */
export const sendRentDueReminders = onSchedule(
  {
    schedule: "0 9 * * *", // 9 AM IST (approx)
    timeZone: "Asia/Kolkata",
    region: "asia-south1",
  },
  async () => {
    const today = new Date();
    const day = today.getDate();

    AppLogger.info("Running rent due reminders", { day });

    try {
      // 1. Fetch active tenants whose rent is due today
      const tenantsSnap = await db.collection("tenants")
        .where("status", "==", "active")
        .where("rentDueDay", "==", day)
        .get();

      if (tenantsSnap.empty) {
        AppLogger.info("No tenants due today");
        return;
      }

      // 2. Batch fetch user profiles to avoid N+1 queries
      const tenantDocs = tenantsSnap.docs;
      const uids = Array.from(new Set(tenantDocs.map(doc => doc.data().authUid).filter(Boolean)));
      const userRefs = uids.map(uid => db.collection("users").doc(uid));
      const userSnaps = uids.length > 0 ? await db.getAll(...userRefs) : [];
      const userMap = new Map(userSnaps.map(s => [s.id, s.data()]));

      AppLogger.info("Processing rent reminders in batches", { total: tenantDocs.length, batchSize: 50 });

      // 3. Process in chunks to improve scalability
      const chunkSize = 50;
      for (let i = 0; i < tenantDocs.length; i += chunkSize) {
        const chunk = tenantDocs.slice(i, i + chunkSize);
        await Promise.all(chunk.map(async (doc) => {
          const tenant = doc.data() as Tenant;
          const uid = tenant.authUid;
          if (!uid) return;

          const userData = userMap.get(uid);
          const fcmToken = userData?.fcmToken;
          if (!fcmToken) return;

          const title = "Rent Due Today";
          const body = `Hi ${tenant.name}, your rent of ₹${tenant.rentAmount} is due today.`;

          // 4. Send notification
          await sendMulticastNotification([fcmToken], {
            title,
            body,
            data: {
              type: "RENT_DUE",
              tenantId: doc.id,
            }
          });

          // 5. Record in-app history
          await recordInAppMessage({
            id: `rent_due_${doc.id}_${today.getTime()}`,
            tenantUserId: uid,
            tenantId: doc.id,
            ownerId: tenant.ownerId,
            title,
            body,
            type: "RENT_DUE",
            severity: "info",
          });
        }));
      }
    } catch (error) {
      AppLogger.error("Rent reminder scheduler failed", error);
    }
  }
);
