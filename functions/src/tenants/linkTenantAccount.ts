import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, FieldValue } from "../utils/firebase";
import { AppLogger } from "../shared/logger";
import { User, Tenant } from "../shared/types";

/**
 * Callable function to link an authenticated tenant user with an existing 
 * tenant record created by an owner.
 * Ensures that UIDs are correctly mapped and duplicate records are avoided.
 */
export const linkTenantAccount = onCall(
  {
    region: "asia-south1",
    enforceAppCheck: true,
  },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const uid = auth.uid;
    const email = (auth.token.email || "").trim().toLowerCase();
    
    if (!email) {
      throw new HttpsError("failed-precondition", "Authenticated account must have an email");
    }

    AppLogger.info("Attempting to link tenant account", { uid, email });

    try {
      // 1. Ensure user profile exists in 'users' collection
      const userRef = db.collection("users").doc(uid);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        const newUser: Partial<User> = {
          uid,
          email,
          emailLowercase: email,
          role: "tenant",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        await userRef.set(newUser);
        AppLogger.info("Created new user profile during link", { uid });
      }

      // 2. Search for existing record in 'tenants' collection by email
      const tenantsSnap = await db.collection("tenants")
        .where("emailLowercase", "==", email)
        .limit(1)
        .get();

      if (tenantsSnap.empty) {
        AppLogger.info("No existing tenant record found to link", { email });
        return { status: "not_found", message: "No profile found matching this email." };
      }

      const tenantDoc = tenantsSnap.docs[0];
      const tenantData = tenantDoc.data() as Tenant;

      // 3. Prevent linking if already linked to a different UID
      if (tenantData.authUid && tenantData.authUid !== uid) {
        AppLogger.warn("Tenant record already linked to different UID", { 
          email, 
          existingUid: tenantData.authUid, 
          newUid: uid 
        });
        throw new HttpsError("permission-denied", "This profile is already linked to another account.");
      }

      // 4. Perform the link
      await tenantDoc.ref.update({
        authUid: uid,
        status: "active",
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 5. Create tenant mapping so Firestore rules can verify access
      const mappingRef = db.collection("tenants_mapping").doc(uid);
      await mappingRef.set({
        tenantId: tenantDoc.id,
        ownerId: tenantData.ownerId || "",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 6. Update user role if needed
      await userRef.update({
        role: "tenant",
        updatedAt: FieldValue.serverTimestamp(),
      });

      AppLogger.info("Tenant account linked successfully", { uid, tenantId: tenantDoc.id });

      return { status: "success", tenantId: tenantDoc.id };

    } catch (error) {
      if (error instanceof HttpsError) throw error;
      AppLogger.error("Error in linkTenantAccount", error, { uid, email });
      throw new HttpsError("internal", "Failed to link account");
    }
  }
);
