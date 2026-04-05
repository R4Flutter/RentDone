import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { logInfo, logWarn } from "../utils/logger";
import { db } from "../utils/firebase";

const REGION = "asia-south1";

const asString = (value: unknown): string => String(value ?? "").trim();

const assertSupportedRole = (role: string): void => {
  if (role !== "owner" && role !== "tenant") {
    throw new HttpsError("failed-precondition", "invalid-user-role");
  }
};

const readUserRoleOrThrow = async (uid: string): Promise<string> => {
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "user-profile-not-found");
  }

  const role = asString(userDoc.data()?.role).toLowerCase();
  assertSupportedRole(role);
  return role;
};

const syncRoleClaim = async (uid: string, role: string): Promise<void> => {
  const auth = getAuth();
  const userRecord = await auth.getUser(uid);
  const existingClaims = userRecord.customClaims ?? {};
  const mergedClaims = {
    ...existingClaims,
    role,
  };

  await auth.setCustomUserClaims(uid, mergedClaims);
};

export const syncUserRoleToClaims = onDocumentWritten(
  {
    document: "users/{uid}",
    region: REGION,
  },
  async (event) => {
    const uid = asString(event.params.uid);
    if (!uid) {return;}

    const after = event.data?.after;
    if (!after?.exists) {
      return;
    }

    const userData = after.data() ?? {};
    const role = asString(userData.role).toLowerCase();

    if (role !== "owner" && role !== "tenant") {
      logWarn("Skipping role sync for unsupported role", { uid, role });
      return;
    }

    await syncRoleClaim(uid, role);

    logInfo("Synced user role claim from users doc", {
      uid,
      role,
    });
  },
);

export const resyncMyRoleClaim = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const uid = asString(request.auth?.uid);
    if (!uid) {
      throw new HttpsError("unauthenticated", "unauthenticated");
    }

    const role = await readUserRoleOrThrow(uid);
    await syncRoleClaim(uid, role);

    logInfo("Manually re-synced role claim", { uid, role });
    return { uid, role, synced: true };
  },
);
