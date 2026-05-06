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

  DashboardFirebaseService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    // BUG-08 fix: FirebaseAuth is now injectable for testability.
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _ownerId => _auth.currentUser?.uid;

  Future<List<DashboardPropertyDto>> fetchProperties() async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) return <DashboardPropertyDto>[];

    try {
      final snapshot = await _firestore
          .collection('properties')
          .where('ownerId', isEqualTo: ownerId)
          .get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs
          .map((doc) => DashboardPropertyDto.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('Error fetching dashboard properties: ${e.code}');
      return <DashboardPropertyDto>[];
    }
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
          .get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs
          .map((doc) => DashboardPaymentDto.fromMap(doc.id, doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      // Return empty on permission denied (shouldn't happen)
      if (e.code == 'permission-denied') return <DashboardPaymentDto>[];
      debugPrint('Error fetching dashboard payments: ${e.code}');
      return <DashboardPaymentDto>[];
    } catch (e) {
      // BUG-09 fix: return empty list on all errors, consistent with fetchProperties.
      debugPrint('Error fetching payments: $e');
      return <DashboardPaymentDto>[];
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
          .get(const GetOptions(source: Source.serverAndCache));
      return snapshot.size;
    } on FirebaseException catch (e) {
      debugPrint('Error fetching dashboard tenant count: ${e.code}');
      return 0;
    } catch (e) {
      debugPrint('Error fetching tenant count: $e');
      return 0;
    }
  }

  /// Watch tenant count stream with error recovery.
  ///
  /// NOTE (BUG-10): This reads from the `owners_summary` denormalized cache,
  /// while [fetchTenantCount] reads directly from the `tenants` collection.
  /// The two can temporarily diverge if the Cloud Function that updates
  /// `owners_summary` fails. Prefer this stream for real-time UI; use
  /// [fetchTenantCount] only for one-shot reports/exports.
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

  /// Watch the complete denormalized dashboard summary
  Stream<Map<String, dynamic>?> watchDashboardSummary() async* {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      yield null;
      return;
    }

    try {
      await for (final snapshot
          in _firestore.collection('owners_summary').doc(ownerId).snapshots()) {
        yield snapshot.data();
      }
    } catch (error) {
      debugPrint('Error in watchDashboardSummary stream: $error');
      yield null;
    }
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
