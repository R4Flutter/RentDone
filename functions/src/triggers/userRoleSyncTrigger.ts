import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";

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

const assertAdminCallerOrThrow = async (uid: string): Promise<void> => {
  const auth = getAuth();
  const userRecord = await auth.getUser(uid);
  if (userRecord.customClaims?.admin === true) {
    return;
  }

  const adminDoc = await db.collection("admins").doc(uid).get();
  if (adminDoc.exists && adminDoc.get("active") !== false) {
    return;
  }

  throw new HttpsError("permission-denied", "admin-access-required");
};

const writeRoleAudit = async ({
  actorUid,
  targetUid,
  previousRole,
  nextRole,
}: {
  actorUid: string;
  targetUid: string;
  previousRole: string | null;
  nextRole: string;
}): Promise<void> => {
  await db.collection("admin_audit_logs").add({
    action: "user_role_assignment",
    adminId: actorUid,
    targetId: targetUid,
    oldValue: previousRole,
    newValue: nextRole,
    reason: "admin-role-upgrade",
    timestamp: FieldValue.serverTimestamp(),
  });
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

export const assignUserRole = onCall(
  {
    region: REGION,
    enforceAppCheck: true,
  },
  async (request) => {
    const actorUid = asString(request.auth?.uid);
    if (!actorUid) {
      throw new HttpsError("unauthenticated", "unauthenticated");
    }

    await assertAdminCallerOrThrow(actorUid);

    const targetUid = asString(request.data?.uid);
    const requestedRole = asString(request.data?.role).toLowerCase();

    if (!targetUid) {
      throw new HttpsError("invalid-argument", "target-uid-required");
    }

    assertSupportedRole(requestedRole);

    const userRef = db.collection("users").doc(targetUid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "user-profile-not-found");
    }

    const previousRoleRaw = asString(userSnap.data()?.role).toLowerCase();
    const previousRole = previousRoleRaw || null;

    if (previousRole === requestedRole) {
      return {
        uid: targetUid,
        role: requestedRole,
        updated: false,
      };
    }

    await userRef.set(
      {
        role: requestedRole,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await syncRoleClaim(targetUid, requestedRole);
    await writeRoleAudit({
      actorUid,
      targetUid,
      previousRole,
      nextRole: requestedRole,
    });

    logInfo("Assigned role via admin callable", {
      actorUid,
      targetUid,
      previousRole,
      nextRole: requestedRole,
    });

    return {
      uid: targetUid,
      role: requestedRole,
      updated: true,
    };
  },
);
