import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/entities/tenant_trust_lookup.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';

class OwnerTenantsFirebaseService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  OwnerTenantsFirebaseService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  Stream<List<TenantDto>> watchAllTenants() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<TenantDto>>.empty();
    }

    return _db
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(TenantDto.fromDoc).toList();
        });
  }

  Stream<List<PropertyDto>> watchAllProperties() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<PropertyDto>>.empty();
    }

    return _db
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PropertyDto.fromMap({'id': doc.id, ...doc.data()});
          }).toList();
        });
  }

  Future<int> cleanupOrphanTenants() async {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('Owner session not found. Please sign in again.');
    }

    final propertiesSnapshot = await _db
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final validPropertyIds = propertiesSnapshot.docs
        .map((doc) => doc.id)
        .toSet();

    final tenantsSnapshot = await _db
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final orphanDocs = tenantsSnapshot.docs.where((doc) {
      final propertyId = doc.data()['propertyId']?.toString() ?? '';
      if (propertyId.isEmpty) {
        return true;
      }
      return !validPropertyIds.contains(propertyId);
    }).toList();

    if (orphanDocs.isEmpty) {
      return 0;
    }

    const chunkSize = 400;
    for (var start = 0; start < orphanDocs.length; start += chunkSize) {
      final end = (start + chunkSize) > orphanDocs.length
          ? orphanDocs.length
          : start + chunkSize;
      final batch = _db.batch();
      for (final doc in orphanDocs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    return orphanDocs.length;
  }

  Future<List<TenantTrustLookup>> searchTenantTrustByPhone(
    String phoneInput,
  ) async {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('Owner session not found. Please sign in again.');
    }

    final normalizedPhone = _normalizePhone(phoneInput);
    if (normalizedPhone.isEmpty) {
      return const <TenantTrustLookup>[];
    }

    final hashedPhone = _hashPhone(normalizedPhone);
    final byHash = await _db
        .collection('tenants')
        .where('phoneHash', isEqualTo: hashedPhone)
        .limit(10)
        .get();

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in byHash.docs) {
      docsById[doc.id] = doc;
    }

    if (docsById.isEmpty) {
      final byPhoneExact = await _db
          .collection('tenants')
          .where('phone', isEqualTo: normalizedPhone)
          .limit(10)
          .get();
      for (final doc in byPhoneExact.docs) {
        docsById[doc.id] = doc;
      }
    }

    return docsById.values.map(_toTrustLookup).toList();
  }

  TenantTrustLookup _toTrustLookup(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final trustScore = TenantTrustScore.clamp(
      (data['trustScore'] as num?)?.toInt() ?? TenantTrustScore.defaultScore,
    );

    final onTimePayments = (data['onTimePayments'] as num?)?.toInt() ?? 0;
    final latePayments = (data['latePayments'] as num?)?.toInt() ?? 0;
    final totalPayments = onTimePayments + latePayments;

    final onTimeRate = totalPayments == 0
        ? 0.0
        : double.parse(
            ((onTimePayments * 100) / totalPayments).toStringAsFixed(1),
          );
    final lateRate = totalPayments == 0
        ? 0.0
        : double.parse(
            ((latePayments * 100) / totalPayments).toStringAsFixed(1),
          );

    final tenureYears = _calculateTenureYears(data);

    final badge = (data['trustBadge'] as String?)?.trim();
    final trustBadge = (badge != null && badge.isNotEmpty)
        ? badge
        : TenantTrustScore.badgeFor(trustScore).label;

    return TenantTrustLookup(
      tenantId: doc.id,
      tenantName: (data['fullName'] as String?)?.trim().isNotEmpty == true
          ? (data['fullName'] as String).trim()
          : (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Tenant',
      trustScore: trustScore,
      trustBadge: trustBadge,
      onTimePaymentRate: onTimeRate,
      latePaymentRate: lateRate,
      tenureYears: tenureYears,
    );
  }

  double _calculateTenureYears(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final baseline =
        parseDate(data['moveInDate']) ??
        parseDate(data['leaseStartDate']) ??
        parseDate(data['createdAt']);

    if (baseline == null) {
      return 0.0;
    }

    final days = DateTime.now().difference(baseline).inDays;
    if (days <= 0) {
      return 0.0;
    }

    return double.parse((days / 365).toStringAsFixed(1));
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  String _hashPhone(String normalizedPhone) {
    return sha256.convert(utf8.encode(normalizedPhone)).toString();
  }
}
