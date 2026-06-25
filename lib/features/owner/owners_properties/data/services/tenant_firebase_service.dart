import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/core/exceptions/security_exceptions.dart';
import 'package:rentdone/core/logging/app_logger.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import 'package:rentdone/features/owner/add_tenant/data/services/firebase_storage_service.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';

class TenantFirebaseService {
  final FirebaseFirestore _db;
  final FirebaseDocumentStorageService _storageService;
  final FirebaseAuth _auth;

  static const String _defaultPlan = 'free';
  static const int _defaultTenantLimit = 2;

  TenantFirebaseService({
    FirebaseFirestore? firestore,
    FirebaseDocumentStorageService? storageService,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storageService = storageService ?? FirebaseDocumentStorageService(),
       _auth = auth ?? FirebaseAuth.instance;

  String _currentUidOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('User not authenticated');
    }
    return uid;
  }

  Stream<List<TenantDto>> watchAllTenants(String ownerId) {
    try {
      if (ownerId.isEmpty) {
        return const Stream<List<TenantDto>>.empty();
      }

      return _db
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map(TenantDto.fromDoc).toList();
          });
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error watching all tenants');
      return Stream.error(e);
    }
  }

  Stream<List<TenantDto>> watchPropertyTenants(String propertyId) {
    try {
      return _db
          .collection('tenants')
          .where('propertyId', isEqualTo: propertyId)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(TenantDto.fromDoc).toList());
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error watching property tenants');
      return Stream.error(e);
    }
  }

  Future<TenantDto?> getTenantById(String tenantId) async {
    try {
      final doc = await _db.collection('tenants').doc(tenantId).get();
      if (!doc.exists) return null;
      return TenantDto.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error getting tenant by id');
      rethrow;
    }
  }

  Future<void> addTenant(TenantDto tenant) async {
    final uid = _currentUidOrThrow();
    
    try {
      final tenantRef = _db.collection('tenants').doc(tenant.id);
      final propertyRef = _db.collection('properties').doc(tenant.propertyId);
      
      // SECURITY: Force ownerId to be the current user
      final ownerId = uid;
      final ownerRef = _db.collection('owners').doc(ownerId);
      
      final tenantMap = tenant.toMap();
      tenantMap['ownerId'] = ownerId; // Overwrite client-provided ID
      
      final normalizedPhone = _normalizePhone(tenant.phone);
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

      await _db.runTransaction((txn) async {
        final propertyDoc = await txn.get(propertyRef);
        if (!propertyDoc.exists) {
          throw StateError('Selected property does not exist');
        }
        
        final propData = propertyDoc.data() ?? {};
        if ((propData['ownerId'] as String? ?? '').trim() != uid) {
          throw UnauthorizedException('Unauthorized property access');
        }

        final ownerDoc = await txn.get(ownerRef);
        final ownerData = ownerDoc.data() ?? <String, dynamic>{};
        final currentCount =
            (ownerData['currentTenantCount'] as num?)?.toInt() ?? 0;

        final data = propertyDoc.data();
        final rooms = _normalizeRooms(data?['rooms']);
        final roomIndex = rooms.indexWhere((room) => room['id'] == tenant.roomId);

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

        rooms[roomIndex] = {...room, 'isOccupied': true, 'tenantId': tenant.id};

        txn.set(tenantRef, tenantMap);
        txn.update(propertyRef, {'rooms': rooms});

        final nextCount = currentCount + 1;
        final tenantLimit =
            (ownerData['tenantLimit'] as num?)?.toInt() ?? _defaultTenantLimit;
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
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error adding tenant');
      rethrow;
    }
  }

  Future<void> removeTenant({
    required String tenantId,
    required String propertyId,
    required String roomId,
  }) async {
    final uid = _currentUidOrThrow();
    
    try {
      final tenantRef = _db.collection('tenants').doc(tenantId);
      final propertyRef = _db.collection('properties').doc(propertyId);

      await _db.runTransaction((txn) async {
        final tenantDoc = await txn.get(tenantRef);
        if (!tenantDoc.exists) {
          throw StateError('Tenant record not found');
        }
        
        final tenantData = tenantDoc.data() ?? <String, dynamic>{};
        final ownerId = (tenantData['ownerId'] as String? ?? '').trim();
        
        // SECURITY: Verify ownership of tenant
        if (ownerId != uid) {
          throw UnauthorizedException('Unauthorized tenant removal attempt');
        }
        
        final ownerRef = _db.collection('owners').doc(ownerId);
        final ownerDoc = await txn.get(ownerRef);
        final ownerData = ownerDoc.data() ?? <String, dynamic>{};

        final propertyDoc = await txn.get(propertyRef);
        if (!propertyDoc.exists) {
          throw StateError('Selected property does not exist');
        }
        
        // SECURITY: Verify ownership of property
        if ((propertyDoc.data()?['ownerId'] as String? ?? '').trim() != uid) {
          throw UnauthorizedException('Unauthorized property access');
        }

        final data = propertyDoc.data();
        final rooms = _normalizeRooms(data?['rooms']);
        final roomIndex = rooms.indexWhere((room) => room['id'] == roomId);

        if (roomIndex == -1) {
          throw StateError('Selected room does not exist in this property');
        }

        final room = rooms[roomIndex];
        rooms[roomIndex] = {...room, 'isOccupied': false, 'tenantId': null};

        txn.update(propertyRef, {'rooms': rooms});

        final currentCount =
            (ownerData['currentTenantCount'] as num?)?.toInt() ?? 0;
        final nextCount = currentCount > 0 ? currentCount - 1 : 0;

        txn.set(ownerRef, {
          'ownerId': ownerId,
          'subscriptionPlan': ownerData['subscriptionPlan'] ?? _defaultPlan,
          'tenantLimit':
              (ownerData['tenantLimit'] as num?)?.toInt() ??
              _defaultTenantLimit,
          'currentTenantCount': nextCount,
          'paymentStatus': ownerData['paymentStatus'] ?? 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      try {
        await tenantRef.delete();
        // Delete documents from storage
        await _storageService.deleteTenantDocuments(tenantId: tenantId);
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied' || error.code == 'not-found') {
          return;
        }
        rethrow;
      }
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error removing tenant');
      rethrow;
    }
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
