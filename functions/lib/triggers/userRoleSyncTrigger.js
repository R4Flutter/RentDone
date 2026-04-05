"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resyncMyRoleClaim = exports.syncUserRoleToClaims = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const auth_1 = require("firebase-admin/auth");
const https_1 = require("firebase-functions/v2/https");
const logger_1 = require("../utils/logger");
const firebase_1 = require("../utils/firebase");
const REGION = "asia-south1";
const asString = (value) => String(value ?? "").trim();
const assertSupportedRole = (role) => {
    if (role !== "owner" && role !== "tenant") {
        throw new https_1.HttpsError("failed-precondition", "invalid-user-role");
    }
};
const readUserRoleOrThrow = async (uid) => {
    const userDoc = await firebase_1.db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError("not-found", "user-profile-not-found");
    }
    const role = asString(userDoc.data()?.role).toLowerCase();
    assertSupportedRole(role);
    return role;
};
const syncRoleClaim = async (uid, role) => {
    const auth = (0, auth_1.getAuth)();
    const userRecord = await auth.getUser(uid);
    const existingClaims = userRecord.customClaims ?? {};
    const mergedClaims = {
        ...existingClaims,
        role,
    };
    await auth.setCustomUserClaims(uid, mergedClaims);
};
exports.syncUserRoleToClaims = (0, firestore_1.onDocumentWritten)({
    document: "users/{uid}",
    region: REGION,
}, async (event) => {
    const uid = asString(event.params.uid);
    if (!uid)
        return;
    const after = event.data?.after;
    if (!after?.exists) {
        return;
    }
    const userData = after.data() ?? {};
    const role = asString(userData.role).toLowerCase();
    if (role !== "owner" && role !== "tenant") {
        (0, logger_1.logWarn)("Skipping role sync for unsupported role", { uid, role });
        return;
    }
    await syncRoleClaim(uid, role);
    (0, logger_1.logInfo)("Synced user role claim from users doc", {
        uid,
        role,
    });
});
exports.resyncMyRoleClaim = (0, https_1.onCall)({
    region: REGION,
    enforceAppCheck: true,
}, async (request) => {
    const uid = asString(request.auth?.uid);
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "unauthenticated");
    }
    const role = await readUserRoleOrThrow(uid);
    await syncRoleClaim(uid, role);
    (0, logger_1.logInfo)("Manually re-synced role claim", { uid, role });
    return { uid, role, synced: true };
});
//# sourceMappingURL=userRoleSyncTrigger.js.map