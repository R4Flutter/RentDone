import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/models/tenant_trust.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/utils/phone_normalizer.dart';

class TenantTrustService {
  TenantTrustService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<TenantTrust?> getTrustScore(String phone) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const TenantTrustAuthException(
        'Please login to access tenant trust lookup.',
      );
    }

    final normalizedPhone = normalizePhone(phone);
    if (!_isValidIndianPhone(normalizedPhone)) {
      throw const TenantTrustValidationException(
        'Please enter a valid 10-digit phone number.',
      );
    }

    try {
      final snapshot = await _firestore
          .collection('tenantTrust')
          .doc(normalizedPhone)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      final data = snapshot.data();
      if (data == null) {
        return null;
      }

      return TenantTrust.fromMap(data);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const TenantTrustPermissionException('Access permission denied.');
      }

      if (error.code == 'unavailable' ||
          error.code == 'network-request-failed') {
        throw const TenantTrustNetworkException(
          'Please check internet connection.',
        );
      }

      throw TenantTrustDataException(
        error.message ?? 'Unable to load tenant trust information.',
      );
    }
  }

  bool _isValidIndianPhone(String value) {
    return RegExp(r'^[6-9][0-9]{9}$').hasMatch(value);
  }
}

class TenantTrustAuthException implements Exception {
  const TenantTrustAuthException(this.message);
  final String message;
}

class TenantTrustPermissionException implements Exception {
  const TenantTrustPermissionException(this.message);
  final String message;
}

class TenantTrustNetworkException implements Exception {
  const TenantTrustNetworkException(this.message);
  final String message;
}

class TenantTrustValidationException implements Exception {
  const TenantTrustValidationException(this.message);
  final String message;
}

class TenantTrustDataException implements Exception {
  const TenantTrustDataException(this.message);
  final String message;
}
