import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_payment_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_property_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_tenant_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/message_model.dart';

class DashboardFirebaseService {
  static const int _dashboardPropertiesLimit = 50;
  static const int _dashboardPaymentsLimit = 50;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DashboardFirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  String? get _ownerId => _auth.currentUser?.uid;

  Future<List<DashboardPropertyDto>> fetchProperties() async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) return <DashboardPropertyDto>[];

    final snapshot = await _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return snapshot.docs
        .map((doc) => DashboardPropertyDto.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<DashboardPropertyDto>> watchProperties() {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<DashboardPropertyDto>>.empty();
    }

    return _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .limit(_dashboardPropertiesLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DashboardPropertyDto.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Fetch payments with error handling
  /// Returns empty list on auth failure, throws on network errors
  Future<List<DashboardPaymentDto>> fetchPayments() async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) return <DashboardPaymentDto>[];

    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .get();
      return snapshot.docs
          .map((doc) => DashboardPaymentDto.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      // Return empty on permission denied (shouldn't happen)
      if (e.code == 'permission-denied') return <DashboardPaymentDto>[];
      // For network errors, rethrow to be handled upstream
      rethrow;
    } catch (e) {
      debugPrint('Error fetching payments: $e');
      rethrow;
    }
  }

  /// Watch payments stream with error recovery
  /// Returns empty stream on auth failure, error handling in repository
  Stream<List<DashboardPaymentDto>> watchPayments() {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<DashboardPaymentDto>>.empty();
    }

    return _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .limit(_dashboardPaymentsLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DashboardPaymentDto.fromMap(doc.id, doc.data()))
              .toList(),
        )
        .handleError((error) {
          debugPrint('Error in watchPayments stream: $error');
          // Log error and return empty list as fallback
          return <DashboardPaymentDto>[];
        });
  }

  /// Fetch tenant count with error handling
  /// Returns 0 on auth failure or error
  Future<int> fetchTenantCount() async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection('tenants')
          .where('ownerId', isEqualTo: ownerId)
          .get();
      return snapshot.size;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 0;
      rethrow;
    } catch (e) {
      debugPrint('Error fetching tenant count: $e');
      return 0;
    }
  }

  /// Watch tenant count stream with error recovery
  Stream<int> watchTenantCount() {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<int>.empty();
    }

    return _firestore
        .collection('owners_summary')
        .doc(ownerId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return 0;
          return (data['tenantCount'] as num?)?.toInt() ??
              (data['totalTenants'] as num?)?.toInt() ??
              0;
        })
        .handleError((error) {
          debugPrint('Error in watchTenantCount stream: $error');
          return 0;
        });
  }

  /// Watch recent messages with error handling
  /// Returns empty stream on failure
  Stream<List<AppMessageDto>> watchRecentMessages({int limit = 6}) {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<AppMessageDto>>.empty();
    }

    return _firestore
        .collection('messages')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppMessageDto.fromDoc).toList())
        .handleError((error) {
          debugPrint('Error in watchRecentMessages stream: $error');
          return <AppMessageDto>[];
        });
  }

  /// Watch tenant activity stream for owner dashboard timeline.
  Stream<List<DashboardTenantDto>> watchTenantActivity({int limit = 20}) {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<DashboardTenantDto>>.empty();
    }

    return _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DashboardTenantDto.fromMap(doc.id, doc.data()))
              .toList(),
        )
        .handleError((error) {
          debugPrint('Error in watchTenantActivity stream: $error');
          return <DashboardTenantDto>[];
        });
  }
}
