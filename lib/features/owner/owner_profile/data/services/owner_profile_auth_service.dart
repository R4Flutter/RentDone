import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/core/services/gravatar_service.dart';
import 'package:rentdone/features/owner/owner_profile/data/models/owner_profile_dto.dart';

class OwnerProfileAuthService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  OwnerProfileAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  Future<OwnerProfileDto> getOwnerProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to continue.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? const <String, dynamic>{};
    final uid = user.uid.trim();
    final memberSuffix = uid.isEmpty
        ? '----'
        : uid.substring(0, uid.length >= 4 ? 4 : uid.length).toUpperCase();

    final roleCode = (data['role'] as String?)?.trim().toLowerCase();
    final roleLabel = roleCode == 'tenant' ? 'Tenant' : 'Property Owner';

    // Get email for Gravatar generation
    final userEmail = _resolveValue(data['email'] as String?, user.email ?? '');

    // Generate Gravatar URL from email if no custom photoUrl exists
    final customPhotoUrl = _resolveValue(
      data['photoUrl'] as String?,
      user.photoURL ?? '',
    );
    final gravatarUrl = GravatarService.getGravatarUrlWithFallback(
      userEmail,
      size: 400,
      fallbackType: 'identicon',
    );

    // Use custom photo if available, otherwise use Gravatar
    final finalPhotoUrl = customPhotoUrl.isNotEmpty
        ? customPhotoUrl
        : gravatarUrl;

    return OwnerProfileDto(
      fullName: _resolveValue(
        data['name'] as String?,
        user.displayName ?? 'Owner',
      ),
      email: userEmail,
      phone: _resolveValue(data['phone'] as String?, user.phoneNumber ?? ''),
      role: roleLabel,
      location: _resolveValue(data['locationAddress'] as String?, ''),
      status: _resolveValue(data['status'] as String?, 'Active'),
      memberId: _resolveValue(data['memberId'] as String?, '#RD-$memberSuffix'),
      avatarCode: _resolveValue(data['avatarCode'] as String?, 'male'),
      photoUrl: finalPhotoUrl,
    );
  }

  Future<OwnerProfileDto> saveOwnerProfile(OwnerProfileDto profile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to update profile.');
    }

    final nextEmail = profile.email.trim();
    final normalizedEmail = nextEmail.toLowerCase();

    if (normalizedEmail.isNotEmpty) {
      final duplicate = await _firestore
          .collection('users')
          .where('emailLowercase', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (duplicate.docs.isNotEmpty && duplicate.docs.first.id != user.uid) {
        throw StateError('Email is already in use by another account.');
      }
    }

    final currentEmail = user.email?.trim() ?? '';
    if (nextEmail.isNotEmpty &&
        nextEmail.toLowerCase() != currentEmail.toLowerCase()) {
      try {
        await user.verifyBeforeUpdateEmail(nextEmail);
      } on FirebaseAuthException catch (error) {
        throw StateError(_mapAuthError(error));
      }
    }

    final nextName = profile.fullName.trim();
    if (nextName.isNotEmpty && nextName != (user.displayName ?? '')) {
      await user.updateDisplayName(nextName);
    }

    final now = FieldValue.serverTimestamp();
    final uid = user.uid.trim();
    final memberSuffix = uid.isEmpty
        ? '----'
        : uid.substring(0, uid.length >= 4 ? 4 : uid.length).toUpperCase();
    final normalizedMemberId = profile.memberId.trim().isEmpty
        ? '#RD-$memberSuffix'
        : profile.memberId.trim();

    // Generate Gravatar URL for the user's email
    final gravatarUrl = GravatarService.getGravatarUrlWithFallback(
      nextEmail.isNotEmpty ? nextEmail : (user.email ?? ''),
      size: 400,
      fallbackType: 'identicon',
    );

    // Use custom photo if provided, otherwise use Gravatar
    final customPhoto = profile.photoUrl.trim();
    final finalPhotoUrl = customPhoto.isNotEmpty ? customPhoto : gravatarUrl;

    final payload = <String, dynamic>{
      'uid': user.uid,
      'name': nextName,
      'email': nextEmail,
      'emailLowercase': normalizedEmail,
      'phone': profile.phone.trim(),
      'locationAddress': profile.location.trim(),
      'status': profile.status.trim().isEmpty
          ? 'Active'
          : profile.status.trim(),
      'memberId': normalizedMemberId,
      'avatarCode': profile.avatarCode.trim().isEmpty
          ? 'male'
          : profile.avatarCode.trim(),
      'photoUrl': finalPhotoUrl,
      'gravatarUrl': gravatarUrl, // Store Gravatar URL separately for reference
      'updatedAt': now,
    };

    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (!existing.exists) {
      payload['createdAt'] = now;
      payload['role'] = 'owner';
    }

    await docRef.set(payload, SetOptions(merge: true));
    await user.reload();
    return getOwnerProfile();
  }

  String _resolveValue(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Email is already in use.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'requires-recent-login':
        return 'For security, please sign in again before changing email.';
      default:
        return error.message ?? 'Unable to update email at the moment.';
    }
  }
}
