import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import '../models/payment_dto.dart';

/// Firestore service for payment/transaction data operations
class PaymentFirestoreService {
  final FirebaseFirestore _firestore;

  PaymentFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Record a payment
  Future<void> recordPayment(PaymentDTO paymentDTO) async {
    try {
      final paymentsRef = _firestore.collection('payments');
      final paymentRef = paymentDTO.id.trim().isEmpty
          ? paymentsRef.doc()
          : paymentsRef.doc(paymentDTO.id);

      final savedPayment = PaymentDTO(
        id: paymentRef.id,
        tenantId: paymentDTO.tenantId,
        ownerId: paymentDTO.ownerId,
        propertyId: paymentDTO.propertyId,
        amount: paymentDTO.amount,
        paymentDate: paymentDTO.paymentDate,
        monthFor: paymentDTO.monthFor,
        paymentMethod: paymentDTO.paymentMethod,
        status: paymentDTO.status,
        createdAt: paymentDTO.createdAt,
        referenceId: paymentDTO.referenceId,
        notes: paymentDTO.notes,
      );

      final tenantRef = _firestore
          .collection('tenants')
          .doc(savedPayment.tenantId);

      await _firestore.runTransaction((txn) async {
        final tenantDoc = await txn.get(tenantRef);
        final tenantData = tenantDoc.data() ?? <String, dynamic>{};

        final currentScore = TenantTrustScore.clamp(
          (tenantData['trustScore'] as num?)?.toInt() ??
              TenantTrustScore.defaultScore,
        );

        final dueDay =
            (tenantData['rentDueDate'] as num?)?.toInt() ??
            (tenantData['rentDueDay'] as num?)?.toInt() ??
            1;
        final dueDate = _resolveDueDate(
          monthFor: savedPayment.monthFor,
          dueDay: dueDay,
        );

        final paymentDelta = TenantTrustScore.paymentDelta(
          paymentDate: savedPayment.paymentDate,
          dueDate: dueDate,
          status: savedPayment.status,
        );

        final isOnTime = paymentDelta > 0;
        final nextConsecutiveOnTime = isOnTime
            ? ((tenantData['consecutiveOnTimeMonths'] as num?)?.toInt() ?? 0) +
                  1
            : 0;
        final bonus = TenantTrustScore.consecutiveBonus(
          consecutiveOnTimeMonths: nextConsecutiveOnTime,
          perfectRecord: isOnTime,
        );
        final newScore = TenantTrustScore.clamp(
          currentScore + paymentDelta + bonus,
        );

        final wasLate = !isOnTime;
        final onTimePayments =
            ((tenantData['onTimePayments'] as num?)?.toInt() ?? 0) +
            (isOnTime ? 1 : 0);
        final latePayments =
            ((tenantData['latePayments'] as num?)?.toInt() ?? 0) +
            (wasLate ? 1 : 0);
        final missedPayments =
            ((tenantData['missedPayments'] as num?)?.toInt() ?? 0) +
            (savedPayment.status.trim().toLowerCase() == 'missed' ? 1 : 0);

        txn.set(paymentRef, savedPayment.toMap(), SetOptions(merge: false));

        txn.set(tenantRef, {
          'trustScore': newScore,
          'trustBadge': TenantTrustScore.badgeFor(newScore).label,
          'onTimePayments': onTimePayments,
          'latePayments': latePayments,
          'missedPayments': missedPayments,
          'consecutiveOnTimeMonths': nextConsecutiveOnTime,
          'lastTrustScoreDelta': paymentDelta + bonus,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final eventRef = tenantRef.collection('trust_score_events').doc();
        txn.set(eventRef, {
          'type': 'payment',
          'paymentId': savedPayment.id,
          'paymentMonth': savedPayment.monthFor,
          'previousScore': currentScore,
          'delta': paymentDelta,
          'bonus': bonus,
          'newScore': newScore,
          'dueDate': Timestamp.fromDate(dueDate),
          'paymentDate': Timestamp.fromDate(savedPayment.paymentDate),
          'createdAt': FieldValue.serverTimestamp(),
          'ownerId': savedPayment.ownerId,
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  DateTime _resolveDueDate({required String monthFor, required int dueDay}) {
    final now = DateTime.now();
    final monthToken = monthFor.trim();
    final monthPattern = RegExp(
      r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})$',
      caseSensitive: false,
    );
    final match = monthPattern.firstMatch(monthToken);

    int year = now.year;
    int month = now.month;

    if (match != null) {
      final monthLabel = match.group(1)!.toLowerCase();
      final parsedYear = int.tryParse(match.group(2)!);
      final monthMap = <String, int>{
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };

      year = parsedYear ?? now.year;
      month = monthMap[monthLabel] ?? now.month;
    }

    final safeDueDay = dueDay.clamp(1, 31).toInt();
    final lastDay = DateTime(year, month + 1, 0).day;
    final cappedDueDay = safeDueDay > lastDay ? lastDay : safeDueDay;

    return DateTime(year, month, cappedDueDay);
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
