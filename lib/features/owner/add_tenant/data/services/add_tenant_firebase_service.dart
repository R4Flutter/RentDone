import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

class AddTenantFirebaseService {
  final FirebaseFirestore _db;

  static const String _defaultPlan = 'free';
  static const int _defaultTenantLimit = 2;

  AddTenantFirebaseService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> addTenant(Tenant tenant) async {
    final dto = TenantDto.fromEntity(tenant);
    final tenantMap = dto.toMap();
    final normalizedPhone = _normalizePhone(dto.phone);
    tenantMap['phoneHash'] = _hashPhone(normalizedPhone);
    final trustScore = TenantTrustScore.clamp(
      (tenantMap['trustScore'] as num?)?.toInt() ??
          TenantTrustScore.defaultScore,
    );
    tenantMap['trustScore'] = trustScore;
    tenantMap['trustBadge'] = TenantTrustScore.badgeFor(trustScore).label;
    tenantMap['onTimePayments'] =
        (tenantMap['onTimePayments'] as num?)?.toInt() ?? 0;
    tenantMap['latePayments'] =
        (tenantMap['latePayments'] as num?)?.toInt() ?? 0;
    tenantMap['missedPayments'] =
        (tenantMap['missedPayments'] as num?)?.toInt() ?? 0;
    tenantMap['consecutiveOnTimeMonths'] =
        (tenantMap['consecutiveOnTimeMonths'] as num?)?.toInt() ?? 0;
    tenantMap['lastTrustScoreDelta'] =
        (tenantMap['lastTrustScoreDelta'] as num?)?.toInt() ?? 0;
    final tenantRef = _db.collection('tenants').doc(dto.id);
    final propertyRef = _db.collection('properties').doc(dto.propertyId);
    final ownerId = (dto.ownerId ?? '').trim();

    if (ownerId.isEmpty) {
      throw StateError('Owner ID is required to add tenant');
    }

    final ownerRef = _db.collection('owners').doc(ownerId);

    await _db.runTransaction((txn) async {
      final propertyDoc = await txn.get(propertyRef);
      if (!propertyDoc.exists) {
        throw StateError('Selected property does not exist');
      }

      final ownerDoc = await txn.get(ownerRef);
      final ownerData = ownerDoc.data() ?? <String, dynamic>{};
      final tenantLimit =
          (ownerData['tenantLimit'] as num?)?.toInt() ?? _defaultTenantLimit;
      final currentCount =
          (ownerData['currentTenantCount'] as num?)?.toInt() ?? 0;
      final paymentStatus = (ownerData['paymentStatus'] as String? ?? 'active')
          .toLowerCase();

      if (paymentStatus == 'pending') {
        throw StateError(
          'Payment is pending. Complete subscription payment to add tenants.',
        );
      }

      if (currentCount >= tenantLimit) {
        throw StateError(
          'You have reached your tenant limit. Upgrade your plan to add more tenants.',
        );
      }

      final data = propertyDoc.data();
      final rooms = _normalizeRooms(data?['rooms']);
      final roomIndex = rooms.indexWhere((room) => room['id'] == dto.roomId);

      if (roomIndex == -1) {
        throw StateError('Selected room does not exist in this property');
      }

      final room = rooms[roomIndex];
      final currentTenantId = room['tenantId']?.toString();
      if (room['isOccupied'] == true &&
          currentTenantId != null &&
          currentTenantId.isNotEmpty) {
        throw StateError('Selected room is already occupied');
      }

      rooms[roomIndex] = {...room, 'isOccupied': true, 'tenantId': dto.id};

      txn.set(tenantRef, tenantMap, SetOptions(merge: true));
      txn.update(propertyRef, {'rooms': rooms});

      final nextCount = currentCount + 1;
      txn.set(ownerRef, {
        'ownerId': ownerId,
        'subscriptionPlan': ownerData['subscriptionPlan'] ?? _defaultPlan,
        'tenantLimit': tenantLimit,
        'currentTenantCount': nextCount,
        'paymentStatus': ownerData['paymentStatus'] ?? 'active',
        'subscriptionStartDate':
            ownerData['subscriptionStartDate'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  List<Map<String, dynamic>> _normalizeRooms(dynamic roomsRaw) {
    if (roomsRaw is! List) return <Map<String, dynamic>>[];

    return roomsRaw
        .whereType<Map>()
        .map((room) => Map<String, dynamic>.from(room))
        .toList();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  String _hashPhone(String normalizedPhone) {
    return sha256.convert(utf8.encode(normalizedPhone)).toString();
  }
}
