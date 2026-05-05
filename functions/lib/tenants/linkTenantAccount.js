"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.linkTenantAccount = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_1 = require("../utils/firebase");
const logger_1 = require("../shared/logger");
/**
 * Callable function to link an authenticated tenant user with an existing
 * tenant record created by an owner.
 * Ensures that UIDs are correctly mapped and duplicate records are avoided.
 */
exports.linkTenantAccount = (0, https_1.onCall)({
    region: "asia-south1",
    enforceAppCheck: true,
}, async (request) => {
    const auth = request.auth;
    if (!auth) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required");
    }
    const uid = auth.uid;
    const email = (auth.token.email || "").trim().toLowerCase();
    if (!email) {
        throw new https_1.HttpsError("failed-precondition", "Authenticated account must have an email");
    }
    logger_1.AppLogger.info("Attempting to link tenant account", { uid, email });
    try {
        // 1. Ensure user profile exists in 'users' collection
        const userRef = firebase_1.db.collection("users").doc(uid);
        const userDoc = await userRef.get();
        if (!userDoc.exists) {
            const newUser = {
                uid,
                email,
                emailLowercase: email,
                role: "tenant",
                createdAt: firebase_1.FieldValue.serverTimestamp(),
                updatedAt: firebase_1.FieldValue.serverTimestamp(),
            };
            await userRef.set(newUser);
            logger_1.AppLogger.info("Created new user profile during link", { uid });
        }
        // 2. Search for existing record in 'tenants' collection by email
        const tenantsSnap = await firebase_1.db.collection("tenants")
            .where("emailLowercase", "==", email)
            .limit(1)
            .get();
        if (tenantsSnap.empty) {
            logger_1.AppLogger.info("No existing tenant record found to link", { email });
            return { status: "not_found", message: "No profile found matching this email." };
        }
        const tenantDoc = tenantsSnap.docs[0];
        const tenantData = tenantDoc.data();
        // 3. Prevent linking if already linked to a different UID
        if (tenantData.authUid && tenantData.authUid !== uid) {
            logger_1.AppLogger.warn("Tenant record already linked to different UID", {
                email,
                existingUid: tenantData.authUid,
                newUid: uid
            });
            throw new https_1.HttpsError("permission-denied", "This profile is already linked to another account.");
        }
        // 4. Perform the link
        await tenantDoc.ref.update({
            authUid: uid,
            status: "active",
            updatedAt: firebase_1.FieldValue.serverTimestamp(),
        });
        // 5. Update user role if needed
        await userRef.update({
            role: "tenant",
            updatedAt: firebase_1.FieldValue.serverTimestamp(),
        });
        logger_1.AppLogger.info("Tenant account linked successfully", { uid, tenantId: tenantDoc.id });
        return { status: "success", tenantId: tenantDoc.id };
    }
    catch (error) {
        if (error instanceof https_1.HttpsError)
            throw error;
        logger_1.AppLogger.error("Error in linkTenantAccount", error, { uid, email });
        throw new https_1.HttpsError("internal", "Failed to link account");
    }
});
//# sourceMappingURL=linkTenantAccount.js.map