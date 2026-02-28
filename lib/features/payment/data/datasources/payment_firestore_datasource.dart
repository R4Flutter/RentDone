import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentFirestoreDataSource {
  final FirebaseFirestore _firestore;

  PaymentFirestoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getActiveLeaseForTenant(String tenantId) async {
    final snap = await _firestore
        .collection('leases')
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  Future<Map<String, dynamic>?> getPaymentForLeaseMonth({
    required String leaseId,
    required int month,
    required int year,
  }) async {
    final snap = await _firestore
        .collection('payments')
        .where('leaseId', isEqualTo: leaseId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  Future<Map<String, dynamic>?> getLatestTransactionForPayment(
    String paymentId,
  ) async {
    final snap = await _firestore
        .collection('transactions')
        .where('paymentId', isEqualTo: paymentId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getTransactions({
    required String field,
    required String value,
    required int limit,
    int? year,
    String? status,
    DateTime? startAfterCreatedAt,
    String? startAfterDocId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('transactions')
        .where(field, isEqualTo: value)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (year != null) {
      final start = DateTime(year, 1, 1);
      final end = DateTime(year + 1, 1, 1);
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end);
    }

    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    if (startAfterCreatedAt != null && startAfterDocId != null) {
      query = query.startAfter([startAfterCreatedAt, startAfterDocId]);
    }

    try {
      return await query.limit(limit).get();
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }

      Query<Map<String, dynamic>> fallback = _firestore
          .collection('transactions')
          .where(field, isEqualTo: value);

      final expandedLimit = limit * 8;
      return fallback.limit(expandedLimit).get();
    }
  }
}
