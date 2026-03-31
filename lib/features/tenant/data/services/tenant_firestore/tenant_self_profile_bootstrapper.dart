import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';

import 'tenant_phone_hash.dart';

class TenantSelfProfileBootstrapper {
  final FirebaseFirestore firestore;

  const TenantSelfProfileBootstrapper(this.firestore);

  Future<void> ensure({
    required String uid,
    required String email,
    String? displayName,
    String? phoneNumber,
  }) async {
    final tenantRef = firestore.collection('tenants').doc(uid);
    if ((await tenantRef.get()).exists) return;

    final normalizedPhone = (phoneNumber ?? '').trim();
    await tenantRef.set({
      'authUid': uid,
      'email': email,
      'emailLowercase': email.trim().toLowerCase(),
      'name': (displayName ?? '').trim().isNotEmpty
          ? displayName!.trim()
          : email.split('@').first,
      'phoneNumber': normalizedPhone,
      'phoneHash': hashTenantPhone(normalizeTenantPhone(normalizedPhone)),
      'ownerId': '',
      'roomNumber': '-',
      'propertyName': '',
      'ownerPhoneNumber': '',
      'rentAmount': 0,
      'rentDueDay': 1,
      'dueAmount': 0,
      'totalPaid': 0,
      'trustScore': TenantTrustScore.defaultScore,
      'trustBadge': TenantTrustScore.badgeFor(
        TenantTrustScore.defaultScore,
      ).label,
      'onTimePayments': 0,
      'latePayments': 0,
      'missedPayments': 0,
      'consecutiveOnTimeMonths': 0,
      'isActive': false,
      'onboardingStatus': 'pending_assignment',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
