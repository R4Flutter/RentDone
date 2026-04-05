import { createHash } from "node:crypto";
import { FieldValue, db } from "../utils/firebase";
import { UserTokenBundle } from "../types/domain";
import { logError, logWarn } from "../utils/logger";

const DEVICE_TOKEN_SUBCOLLECTION = "deviceTokens";

const normalizeToken = (token: string): string => token.trim();

const tokenDocId = (token: string): string =>
  createHash("sha256").update(token).digest("hex");

const sanitizePlatform = (platform: string): "android" | "ios" | "web" | "unknown" => {
  const value = platform.trim().toLowerCase();
  if (value === "android" || value === "ios" || value === "web") {
    return value;
  }
  return "unknown";
};

export const upsertDeviceToken = async (
  userId: string,
  rawToken: string,
  rawPlatform: string,
): Promise<void> => {
  const token = normalizeToken(rawToken);
  if (!token) {
    throw new Error("Token must not be empty");
  }

  const platform = sanitizePlatform(rawPlatform);
  const now = FieldValue.serverTimestamp();
  const id = tokenDocId(token);
  const tokenRef = db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).doc(id);

  await db.runTransaction(async (txn) => {
    const current = await txn.get(tokenRef);
    txn.set(
      tokenRef,
      {
        token,
        platform,
        createdAt: current.exists ? current.get("createdAt") ?? now : now,
        lastUsedAt: now,
      },
      { merge: true },
    );
  });
};

export const removeDeviceToken = async (userId: string, rawToken: string): Promise<void> => {
  const token = normalizeToken(rawToken);
  if (!token) {
    return;
  }

  const id = tokenDocId(token);
  await db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).doc(id).delete();
};

export const getUserDeviceTokens = async (userId: string): Promise<UserTokenBundle> => {
  const tokenSnap = await db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).get();

  const tokenRefs = new Map<string, FirebaseFirestore.DocumentReference>();
  const uniqueTokens = new Set<string>();

  tokenSnap.forEach((doc) => {
    const token = String(doc.get("token") ?? "").trim();
    if (!token) {
      return;
    }
    uniqueTokens.add(token);
    tokenRefs.set(token, doc.ref);
  });

  return {
    tokens: [...uniqueTokens],
    tokenRefs,
  };
};

export const cleanupInvalidTokens = async (
  tokenRefs: Map<string, FirebaseFirestore.DocumentReference>,
  invalidTokens: string[],
): Promise<void> => {
  if (invalidTokens.length === 0) {
    return;
  }

  const batch = db.batch();
  let deleted = 0;

  for (const token of invalidTokens) {
    const ref = tokenRefs.get(token);
    if (!ref) {
      continue;
    }
    batch.delete(ref);
    deleted += 1;
  }

  if (deleted === 0) {
    return;
  }

  try {
    await batch.commit();
  } catch (error) {
    logError("cleanupInvalidTokens failed", {
      deleted,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
};

export const touchDeviceTokenUsage = async (userId: string, rawToken: string): Promise<void> => {
  const token = normalizeToken(rawToken);
  if (!token) {
    return;
  }

  const id = tokenDocId(token);
  const ref = db.collection("users").doc(userId).collection(DEVICE_TOKEN_SUBCOLLECTION).doc(id);
  try {
    await ref.set({ lastUsedAt: FieldValue.serverTimestamp() }, { merge: true });
  } catch (error) {
    logWarn("touchDeviceTokenUsage failed", {
      userId,
      tokenId: id,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
};
