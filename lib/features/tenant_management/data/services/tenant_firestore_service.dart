import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/tenant_dto.dart';

/// Firestore service for tenant data operations
/// Handles all database read/write operations
class TenantFirestoreService {
  final FirebaseFirestore _firestore;

  static const String _defaultPlan = 'free';
  static const int _defaultTenantLimit = 2;

  TenantFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Add a new tenant to Firestore
  /// Structure: /tenants/{tenantId}
  Future<void> addTenant(TenantDTO tenantDTO) async {
    final map = tenantDTO.toMap();
    final normalizedPhone = _normalizePhone(tenantDTO.phone);
    map['phoneHash'] = _hashPhone(normalizedPhone);
    map['trustScore'] = _clampTrustScore(
      (map['trustScore'] as num?)?.toInt() ?? 50,
    );

    final ownerId = tenantDTO.ownerId.trim();
    if (ownerId.isEmpty) {
      throw StateError('Owner ID is required to add tenant');
    }

    final tenantRef = _firestore.collection('tenants').doc(tenantDTO.id);
    final ownerRef = _firestore.collection('owners').doc(ownerId);

    await _firestore.runTransaction((txn) async {
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

      txn.set(tenantRef, map, SetOptions(merge: false));

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

  /// Get tenant by ID
  Future<TenantDTO?> getTenant(String tenantId) async {
    try {
      final doc = await _firestore.collection('tenants').doc(tenantId).get();
      if (doc.exists) {
        return TenantDTO.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all tenants for an owner (paginated)
  Future<List<TenantDTO>> getTenantsForOwner(
    String ownerId, {
    required int limit,
    required int page,
    String? filterStatus,
    String? sortBy,
  }) async {
    try {
      var query = _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId);

      if (filterStatus != null) {
        query = query.where('status', isEqualTo: filterStatus);
      }

      // Apply sorting
      switch (sortBy) {
        case 'rentDueDate':
          query = query.orderBy('rentDueDate');
          break;
        case 'rentAmount':
          query = query.orderBy('rentAmount', descending: true);
          break;
        case 'createdAt':
        default:
          query = query.orderBy('createdAt', descending: true);
      }

      // Pagination - load more docs than needed and skip on client
      final offset = (page - 1) * limit;
      final docs = await query.limit(limit + offset).get();

      // Skip offset docs and take limit docs
      final paginatedDocs = docs.docs.skip(offset).take(limit).toList();

      return paginatedDocs.map((doc) => TenantDTO.fromMap(doc.data())).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get tenants by property
  Future<List<TenantDTO>> getTenantsByProperty(String propertyId) async {
    try {
      final docs = await _firestore
          .collection('tenants')
          .where('propertyId', isEqualTo: propertyId)
          .where('status', isEqualTo: 'active')
          .get();

      return docs.docs.map((doc) => TenantDTO.fromMap(doc.data())).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Update tenant information
  Future<void> updateTenant(TenantDTO tenantDTO) async {
    try {
      final map = tenantDTO.toMap();
      final normalizedPhone = _normalizePhone(tenantDTO.phone);
      map['phoneHash'] = _hashPhone(normalizedPhone);
      map['trustScore'] = _clampTrustScore(
        (map['trustScore'] as num?)?.toInt() ?? 50,
      );

      await _firestore.collection('tenants').doc(tenantDTO.id).update(map);
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate tenant
  Future<void> deactivateTenant(String tenantId) async {
    try {
      final tenantRef = _firestore.collection('tenants').doc(tenantId);
      await _firestore.runTransaction((txn) async {
        final tenantDoc = await txn.get(tenantRef);
        if (!tenantDoc.exists) {
          throw StateError('Tenant not found');
        }

        final tenantData = tenantDoc.data() ?? <String, dynamic>{};
        final ownerId = (tenantData['ownerId'] as String? ?? '').trim();
        final status = (tenantData['status'] as String? ?? '').toLowerCase();
        final isActiveFlag = tenantData['isActive'] == true;
        final wasActive = status == 'active' || isActiveFlag;

        txn.update(tenantRef, {
          'status': 'inactive',
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (ownerId.isEmpty || !wasActive) {
          return;
        }

        final ownerRef = _firestore.collection('owners').doc(ownerId);
        final ownerDoc = await txn.get(ownerRef);
        final ownerData = ownerDoc.data() ?? <String, dynamic>{};
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
    } catch (e) {
      rethrow;
    }
  }

  /// Activate tenant
  Future<void> activateTenant(String tenantId) async {
    try {
      final tenantRef = _firestore.collection('tenants').doc(tenantId);
      await _firestore.runTransaction((txn) async {
        final tenantDoc = await txn.get(tenantRef);
        if (!tenantDoc.exists) {
          throw StateError('Tenant not found');
        }

        final tenantData = tenantDoc.data() ?? <String, dynamic>{};
        final ownerId = (tenantData['ownerId'] as String? ?? '').trim();
        if (ownerId.isEmpty) {
          throw StateError('Tenant owner not found');
        }

        final status = (tenantData['status'] as String? ?? '').toLowerCase();
        final isActiveFlag = tenantData['isActive'] == true;
        final alreadyActive = status == 'active' || isActiveFlag;

        final ownerRef = _firestore.collection('owners').doc(ownerId);
        final ownerDoc = await txn.get(ownerRef);
        final ownerData = ownerDoc.data() ?? <String, dynamic>{};
        final tenantLimit =
            (ownerData['tenantLimit'] as num?)?.toInt() ?? _defaultTenantLimit;
        final currentCount =
            (ownerData['currentTenantCount'] as num?)?.toInt() ?? 0;
        final paymentStatus =
            (ownerData['paymentStatus'] as String? ?? 'active').toLowerCase();

        if (paymentStatus == 'pending') {
          throw StateError(
            'Payment is pending. Complete subscription payment to activate tenants.',
          );
        }

        if (!alreadyActive && currentCount >= tenantLimit) {
          throw StateError(
            'You have reached your tenant limit. Upgrade your plan to add more tenants.',
          );
        }

        txn.update(tenantRef, {
          'status': 'active',
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!alreadyActive) {
          final nextCount = currentCount + 1;
          txn.set(ownerRef, {
            'ownerId': ownerId,
            'subscriptionPlan': ownerData['subscriptionPlan'] ?? _defaultPlan,
            'tenantLimit': tenantLimit,
            'currentTenantCount': nextCount,
            'paymentStatus': ownerData['paymentStatus'] ?? 'active',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Search tenants by name or phone
  Future<List<TenantDTO>> searchTenants(String ownerId, String query) async {
    try {
      final queryLower = query.toLowerCase();
      final normalizedQueryPhone = _normalizePhone(query);
      final hashedQueryPhone = normalizedQueryPhone.isEmpty
          ? ''
          : _hashPhone(normalizedQueryPhone);

      final docs = await _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final results = docs.docs
          .map((doc) => TenantDTO.fromMap(doc.data()))
          .where(
            (tenant) =>
                tenant.fullName.toLowerCase().contains(queryLower) ||
                tenant.phone.contains(query) ||
                (hashedQueryPhone.isNotEmpty &&
                    (tenant.phoneHash ?? '') == hashedQueryPhone),
          )
          .toList();

      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// Get active tenant count
  Future<int> getActiveTenantCount(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      // Fallback for older Firestore versions
      final docs = await _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .get();
      return docs.docs.length;
    }
  }

  /// Get overdue tenants count
  Future<int> getOverdueTenantCount(String ownerId) async {
    try {
      final now = DateTime.now();
      final docs = await _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .get();

      int overdueCount = 0;
      for (final doc in docs.docs) {
        final tenant = TenantDTO.fromMap(doc.data());
        final currentMonthDueDate = DateTime(
          now.year,
          now.month,
          tenant.rentDueDate,
        );
        if (now.isAfter(currentMonthDueDate)) {
          // Check if payment was made for this month
          // This would require checking payments collection
          overdueCount++;
        }
      }

      return overdueCount;
    } catch (e) {
      rethrow;
    }
  }

  /// Get total monthly income
  Future<int> getTotalMonthlyIncome(String ownerId) async {
    try {
      final docs = await _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .get();

      int total = 0;
      for (final doc in docs.docs) {
        final tenant = TenantDTO.fromMap(doc.data());
        // Only include active tenants (already filtered by query)
        total += tenant.rentAmount;
      }

      return total;
    } catch (e) {
      rethrow;
    }
  }

  /// Get pending amount (requires checking payments)
  Future<int> getPendingAmount(String ownerId) async {
    try {
      final docs = await _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .get();

      int pending = 0;
      final now = DateTime.now();

      for (final doc in docs.docs) {
        final tenant = TenantDTO.fromMap(doc.data());
        final currentMonthDueDate = DateTime(
          now.year,
          now.month,
          tenant.rentDueDate,
        );

        if (now.isAfter(currentMonthDueDate)) {
          // Check if payment made for current month
          final payments = await _firestore
              .collection('payments')
              .where('tenantId', isEqualTo: tenant.id)
              .where('monthFor', isEqualTo: _getCurrentMonthString())
              .where('status', isEqualTo: 'paid')
              .get();

          if (payments.docs.isEmpty) {
            pending += tenant.rentAmount;
          }
        }
      }

      return pending;
    } catch (e) {
      rethrow;
    }
  }

  /// Helper: Get current month string (e.g., "Jan 2026")
  String _getCurrentMonthString() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
  }

  String _hashPhone(String normalizedPhone) {
    return sha256.convert(utf8.encode(normalizedPhone)).toString();
  }

  int _clampTrustScore(int score) {
    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }
}
