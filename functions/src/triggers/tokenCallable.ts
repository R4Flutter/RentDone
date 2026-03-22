import { HttpsError, onCall } from "firebase-functions/v2/https";
import { removeDeviceToken, upsertDeviceToken } from "../services/tokenService";
import { logError } from "../utils/logger";

const normalizePlatform = (value: unknown): string => String(value ?? "unknown").trim().toLowerCase();

export const registerDeviceToken = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const token = String(request.data?.token ?? "").trim();
    const platform = normalizePlatform(request.data?.platform);

    if (!token) {
      throw new HttpsError("invalid-argument", "token is required");
    }

    try {
      await upsertDeviceToken(uid, token, platform);
      return { ok: true };
    } catch (error) {
      logError("registerDeviceToken failed", {
        uid,
        error: error instanceof Error ? error.message : String(error),
      });
      throw new HttpsError("internal", "Could not register token");
    }
  },
);

export const unregisterDeviceToken = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const token = String(request.data?.token ?? "").trim();
    if (!token) {
      throw new HttpsError("invalid-argument", "token is required");
    }

    try {
      await removeDeviceToken(uid, token);
      return { ok: true };
    } catch (error) {
      logError("unregisterDeviceToken failed", {
        uid,
        error: error instanceof Error ? error.message : String(error),
      });
      throw new HttpsError("internal", "Could not unregister token");
    }
  },
);
