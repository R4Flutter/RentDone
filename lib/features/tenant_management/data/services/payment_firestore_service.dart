import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_dto.dart';

/// Firestore service for payment/transaction data operations
class PaymentFirestoreService {
  final FirebaseFirestore _firestore;

  PaymentFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Record a payment
  Future<void> recordPayment(PaymentDTO paymentDTO) async {
    try {
      await _firestore
          .collection('payments')
          .doc(paymentDTO.id)
          .set(paymentDTO.toMap(), SetOptions(merge: false));
    } catch (e) {
      rethrow;
    }
  }

  /// Get payment history for tenant (paginated)
  Future<List<PaymentDTO>> getPaymentHistory(
    String tenantId, {
    required int limit,
    required int page,
  }) async {
    try {
      final offset = (page - 1) * limit;
      final docs = await _firestore
          .collection('payments')
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('createdAt', descending: true)
          .limit(limit + offset)
          .get();

      final paginatedDocs = docs.docs.skip(offset).take(limit).toList();
      return paginatedDocs
          .map((doc) => PaymentDTO.fromMap(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all pending payments for owner
  Future<List<PaymentDTO>> getPendingPayments(String ownerId) async {
    try {
      final docs = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', whereIn: ['pending', 'partial'])
          .orderBy('createdAt', descending: true)
          .get();

      return docs.docs.map((doc) => PaymentDTO.fromMap(doc.data())).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get payments by month
  Future<List<PaymentDTO>> getPaymentsByMonth(
    String ownerId,
    String monthFor,
  ) async {
    try {
      final docs = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('monthFor', isEqualTo: monthFor)
          .get();

      return docs.docs.map((doc) => PaymentDTO.fromMap(doc.data())).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Update payment status
  Future<void> updatePaymentStatus(String paymentId, String status) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': status,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get monthly revenue for owner
  Future<int> getMonthlyRevenue(String ownerId) async {
    try {
      final currentMonth = _getCurrentMonthString();
      final docs = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('monthFor', isEqualTo: currentMonth)
          .where('status', isEqualTo: 'paid')
          .get();

      int total = 0;
      for (final doc in docs.docs) {
        final payment = PaymentDTO.fromMap(doc.data());
        total += payment.amount;
      }

      return total;
    } catch (e) {
      rethrow;
    }
  }

  /// Get pending amount due
  Future<int> getPendingAmount(String ownerId) async {
    try {
      final docs = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', whereIn: ['pending', 'partial'])
          .get();

      int total = 0;
      for (final doc in docs.docs) {
        final payment = PaymentDTO.fromMap(doc.data());
        total += payment.amount;
      }

      return total;
    } catch (e) {
      rethrow;
    }
  }

  /// Get overdue amount
  Future<int> getOverdueAmount(String ownerId) async {
    try {
      final now = DateTime.now();
      final docs = await _firestore
          .collection('payments')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', whereIn: ['pending', 'partial'])
          .get();

      int total = 0;
      for (final doc in docs.docs) {
        final payment = PaymentDTO.fromMap(doc.data());
        // If payment date is before today, it's overdue
        if (payment.paymentDate.isBefore(now)) {
          total += payment.amount;
        }
      }

      return total;
    } catch (e) {
      rethrow;
    }
  }

  /// Helper: Get current month string
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
}
