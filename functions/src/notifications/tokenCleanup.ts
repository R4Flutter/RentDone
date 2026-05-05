import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../utils/firebase";
import { AppLogger } from "../shared/logger";

/**
 * Daily cleanup of expired or orphan security and webhook data.
 */
export const cleanupExpiredSystemLogs = onSchedule(
  {
    schedule: "0 3 * * *", // 3 AM UTC
    region: "asia-south1",
    memory: "256MiB",
  },
  async () => {
    const now = new Date();
    AppLogger.info("Starting system log cleanup", { timestamp: now.toISOString() });

    const collections = ["_webhookEvents", "_securitySignals", "_notificationEvents"];
    
    for (const col of collections) {
      try {
        const snapshot = await db.collection(col)
          .where("expiresAt", "<=", now)
          .limit(500)
          .get();

        if (snapshot.empty) continue;

        const batch = db.batch();
        snapshot.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        
        AppLogger.info(`Cleaned up ${snapshot.size} docs from ${col}`);
      } catch (error) {
        AppLogger.error(`Failed to cleanup collection: ${col}`, error);
      }
    }
  }
);
