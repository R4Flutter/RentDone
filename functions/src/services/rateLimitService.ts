import { FieldValue, db } from "../utils/firebase";

const DEFAULT_MAX_PER_DAY: Record<string, number> = {
  PAYMENT_RECEIVED: 20,
  RENT_DUE_REMINDER: 4,
};

export const checkAndIncrementRateLimit = async (
  userId: string,
  notificationType: "PAYMENT_RECEIVED" | "RENT_DUE_REMINDER",
): Promise<boolean> => {
  const dayKey = new Date().toISOString().slice(0, 10);
  const ref = db
    .collection("notificationRateLimits")
    .doc(`${userId}_${notificationType}_${dayKey}`);

  return db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    const currentCount = snap.exists ? Number(snap.get("count") ?? 0) : 0;
    const maxPerDay = DEFAULT_MAX_PER_DAY[notificationType] ?? 10;

    if (currentCount >= maxPerDay) {
      return false;
    }

    txn.set(
      ref,
      {
        userId,
        type: notificationType,
        count: currentCount + 1,
        maxPerDay,
        dayKey,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: snap.exists ? snap.get("createdAt") ?? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return true;
  });
};
