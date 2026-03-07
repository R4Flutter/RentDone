import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import 'package:rentdone/features/owner/owner_payment/data/models/payment_dto.dart';

class PaymentFirebaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PaymentFirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  Stream<List<PaymentDto>> watchPayments() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<PaymentDto>>.empty();
    }

    return _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PaymentDto.fromFirestore(doc.id, doc.data());
          }).toList();
        });
  }

  Future<void> markPaymentPaidCash(String paymentId) async {
    await _markPaymentPaidWithTrustUpdate(paymentId, method: 'cash');
  }

  Future<void> markPaymentPaidOnline(
    String paymentId, {
    String? transactionId,
  }) async {
    await _markPaymentPaidWithTrustUpdate(
      paymentId,
      method: 'online',
      transactionId: transactionId,
    );
  }

  Future<void> _markPaymentPaidWithTrustUpdate(
    String paymentId, {
    required String method,
    String? transactionId,
  }) async {
    final paymentRef = _firestore.collection('payments').doc(paymentId);
    final paidAt = DateTime.now();

    await _firestore.runTransaction((txn) async {
      final paymentDoc = await txn.get(paymentRef);
      if (!paymentDoc.exists) {
        throw StateError('Payment record not found');
      }

      final paymentData = paymentDoc.data() ?? <String, dynamic>{};
      final priorStatus = (paymentData['status'] as String? ?? '')
          .trim()
          .toLowerCase();

      final paymentUpdate = <String, dynamic>{
        'status': 'paid',
        'method': method,
        'paidAt': Timestamp.fromDate(paidAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (transactionId != null && transactionId.trim().isNotEmpty) {
        paymentUpdate['transactionId'] = transactionId.trim();
      }
      txn.update(paymentRef, paymentUpdate);

      // Prevent score inflation if an already-paid payment is edited.
      if (priorStatus == 'paid') {
        return;
      }

      final tenantId = (paymentData['tenantId'] as String? ?? '').trim();
      if (tenantId.isEmpty) {
        return;
      }

      final tenantRef = _firestore.collection('tenants').doc(tenantId);
      final tenantDoc = await txn.get(tenantRef);
      final tenantData = tenantDoc.data() ?? <String, dynamic>{};

      final dueDate = _toDateTime(paymentData['dueDate']) ?? paidAt;
      final currentScore = TenantTrustScore.clamp(
        (tenantData['trustScore'] as num?)?.toInt() ??
            TenantTrustScore.defaultScore,
      );

      final paymentDelta = TenantTrustScore.paymentDelta(
        paymentDate: paidAt,
        dueDate: dueDate,
        status: 'paid',
      );
      final isOnTime = paymentDelta > 0;
      final nextConsecutiveOnTime = isOnTime
          ? ((tenantData['consecutiveOnTimeMonths'] as num?)?.toInt() ?? 0) + 1
          : 0;

      final bonus = TenantTrustScore.consecutiveBonus(
        consecutiveOnTimeMonths: nextConsecutiveOnTime,
        perfectRecord: isOnTime,
      );

      final newScore = TenantTrustScore.clamp(
        currentScore + paymentDelta + bonus,
      );

      final onTimePayments =
          ((tenantData['onTimePayments'] as num?)?.toInt() ?? 0) +
          (isOnTime ? 1 : 0);
      final latePayments =
          ((tenantData['latePayments'] as num?)?.toInt() ?? 0) +
          (!isOnTime ? 1 : 0);

      txn.set(tenantRef, {
        'trustScore': newScore,
        'trustBadge': TenantTrustScore.badgeFor(newScore).label,
        'onTimePayments': onTimePayments,
        'latePayments': latePayments,
        'consecutiveOnTimeMonths': nextConsecutiveOnTime,
        'lastTrustScoreDelta': paymentDelta + bonus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final eventRef = tenantRef.collection('trust_score_events').doc();
      txn.set(eventRef, {
        'type': 'payment_status_update',
        'paymentId': paymentId,
        'previousScore': currentScore,
        'delta': paymentDelta,
        'bonus': bonus,
        'newScore': newScore,
        'dueDate': Timestamp.fromDate(dueDate),
        'paymentDate': Timestamp.fromDate(paidAt),
        'createdAt': FieldValue.serverTimestamp(),
        'ownerId': _auth.currentUser?.uid,
      });
    });
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
