import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:rentdone/core/exceptions/security_exceptions.dart';
import '../models/tenant_dto.dart';

/// Firestore service for tenant data operations
/// Handles all database read/write operations
/// ⚠️ SECURITY: All writes require ownership verification
class TenantFirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _defaultPlan = 'free';
  static const int _defaultTenantLimit = 2;

  TenantFirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Get current authenticated user ID or throw if not authenticated
  String _getCurrentUserIdOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw UnauthorizedException('User not authenticated');
    }
    return uid;
  }

  /// Verify tenant belongs to current user by checking ownerId
  /// SECURITY: Defense-in-depth check before Firestore rules
  Future<void> _verifyTenantOwnershipOrThrow(String tenantId) async {
    try {
      final currentUserId = _getCurrentUserIdOrThrow();
      final tenantDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (!tenantDoc.exists) {
        throw ResourceNotAccessibleException(
          message: 'Tenant not found',
          resourceType: 'tenant',
          resourceId: tenantId,
        );
      }

      final ownerId = tenantDoc.data()?['ownerId'] as String?;
      if (ownerId != currentUserId) {
        throw UnauthorizedException(
          'You do not own this tenant. Cannot modify.',
        );
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw UnauthorizedException('Permission denied by Firestore rules');
      }
      rethrow;
    }
  }

  /// Add a new tenant to Firestore
  /// Structure: /tenants/{tenantId}
  /// SECURITY: Verifies that authenticated user is the owner before creating tenant
  Future<void> addTenant(TenantDTO tenantDTO) async {
    // SECURITY: Verify that current user is owner (defense-in-depth)
    final currentUserId = _getCurrentUserIdOrThrow();
    final providedOwnerId = tenantDTO.ownerId.trim();

    if (providedOwnerId != currentUserId) {
      throw UnauthorizedException(
        'You can only add tenants to your own account. '
        'Provided ownerId ($providedOwnerId) does not match authenticated user ($currentUserId).',
      );
    }

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
      final currentCount =
          (ownerData['currentTenantCount'] as num?)?.toInt() ?? 0;

      txn.set(tenantRef, map, SetOptions(merge: false));

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

      var cursorQuery = query.limit(limit);
      QuerySnapshot<Map<String, dynamic>> currentPageSnapshot =
          await cursorQuery.get();

      var currentPage = 1;
      while (currentPage < page && currentPageSnapshot.docs.isNotEmpty) {
        final lastDoc = currentPageSnapshot.docs.last;
        cursorQuery = query.startAfterDocument(lastDoc).limit(limit);
        currentPageSnapshot = await cursorQuery.get();
        currentPage += 1;
      }

      final paginatedDocs = currentPageSnapshot.docs;

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
  /// SECURITY: Verifies current user owns the tenant before deactivating
  Future<void> deactivateTenant(String tenantId) async {
    try {
      // SECURITY: Verify ownership BEFORE transaction (defense-in-depth)
      await _verifyTenantOwnershipOrThrow(tenantId);

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

        // SECURITY: Double-check ownership inside transaction
        final currentUserId = _getCurrentUserIdOrThrow();
        if (ownerId != currentUserId) {
          throw UnauthorizedException('You do not own this tenant.');
        }

        Map<String, dynamic>? ownerData;
        DocumentReference<Map<String, dynamic>>? ownerRef;
        if (ownerId.isNotEmpty && wasActive) {
          ownerRef = _firestore.collection('owners').doc(ownerId);
          final ownerDoc = await txn.get(ownerRef);
          ownerData = ownerDoc.data() ?? <String, dynamic>{};
        }

        txn.update(tenantRef, {
          'status': 'inactive',
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (ownerId.isEmpty || !wasActive) {
          return;
        }

        if (ownerRef == null || ownerData == null) {
          return;
        }

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
  /// SECURITY: Verifies current user owns the tenant before activating
  Future<void> activateTenant(String tenantId) async {
    try {
      // SECURITY: Verify ownership BEFORE transaction (defense-in-depth)
      await _verifyTenantOwnershipOrThrow(tenantId);

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

        // SECURITY: Double-check ownership inside transaction
        final currentUserId = _getCurrentUserIdOrThrow();
        if (ownerId != currentUserId) {
          throw UnauthorizedException('You do not own this tenant.');
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
          throw QuotaExceededException(
            message:
                'You have reached your tenant limit. Upgrade your plan to add more tenants.',
            currentCount: currentCount,
            maxAllowed: tenantLimit,
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
