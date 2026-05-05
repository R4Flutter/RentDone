import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import 'package:rentdone/features/owner/owner_payment/domain/exceptions/payment_exceptions.dart';

class PaymentWriteService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functionsAsia;
  final FirebaseFunctions _functionsUs;
  final FirebaseAuth _auth;

  PaymentWriteService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functionsAsia,
    FirebaseFunctions? functionsUs,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsAsia = functionsAsia ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
       _functionsUs = functionsUs ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _auth = auth ?? FirebaseAuth.instance;

  static const int _maxPaymentAmount = 5000000;

  String _currentUserIdOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('User is not authenticated.');
    }
    return uid.trim();
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

      DocumentReference<Map<String, dynamic>>? tenantRef;
      Map<String, dynamic>? tenantData;
      if (priorStatus != 'paid') {
        final tenantId = (paymentData['tenantId'] as String? ?? '').trim();
        if (tenantId.isNotEmpty) {
          tenantRef = _firestore.collection('tenants').doc(tenantId);
          final tenantDoc = await txn.get(tenantRef);
          tenantData = tenantDoc.data() ?? <String, dynamic>{};
        }
      }

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

      if (priorStatus == 'paid' || tenantRef == null || tenantData == null) {
        return;
      }

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

  Future<String> addPayment({
    required String tenantId,
    required String propertyId,
    required int amount,
    required DateTime date,
    required String method,
    required String status,
    int? baseAmount,
    int? paidAmount,
    int? remainingAmount,
    String? transactionId,
    String? notes,
  }) async {
    final actorUid = _currentUserIdOrThrow();
    final normalizedTenantId = tenantId.trim();
    final normalizedPropertyId = propertyId.trim();

    if (normalizedTenantId.isEmpty) {
      throw InvalidPaymentContextException.tenantNotFound();
    }
    if (normalizedPropertyId.isEmpty) {
      throw InvalidPaymentContextException.propertyNotFound();
    }
    if (amount <= 0) {
      throw InvalidPaymentAmountException.zero();
    }
    if (amount > _maxPaymentAmount) {
      throw InvalidPaymentAmountException.custom(
        'Payment amount cannot exceed Rs $_maxPaymentAmount',
      );
    }

    final methodLower = method.trim().toLowerCase();
    final backendMethod = methodLower.contains('razorpay')
        ? 'razorpay'
        : 'manual';
    final idempotencyKey = _buildIdempotencyKey(
      actorUid: actorUid,
      tenantId: normalizedTenantId,
      propertyId: normalizedPropertyId,
      amount: amount,
      method: backendMethod,
      date: date,
      nonce: transactionId ?? notes ?? status,
    );

    try {
      final callable = _functionsAsia.httpsCallable('createPayment');
      final result = await callable.call({
        'tenantId': normalizedTenantId,
        'propertyId': normalizedPropertyId,
        'amount': amount,
        'method': backendMethod,
        'idempotencyKey': idempotencyKey,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final paymentId = (data['paymentId'] as String? ?? '').trim();
      if (paymentId.isEmpty) {
        throw PaymentStorageException.custom(
          'Payment created without payment ID',
        );
      }
      return paymentId;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw InvalidPaymentContextException.noOwnership();
      }
      if (e.code == 'unauthenticated') {
        throw InvalidPaymentContextException.noAuth();
      }
      if (e.code == 'invalid-argument') {
        throw InvalidPaymentAmountException.custom(
          e.message ?? 'Invalid payment request',
        );
      }
      if (e.code == 'already-exists') {
        throw PaymentStorageException.custom('Duplicate payment blocked');
      }
      throw PaymentStorageException.write(null);
    }
  }

  Future<void> updatePaymentStatus({
    required String paymentId,
    required String newStatus,
    int? installmentAmount,
    String? installmentMethod,
    String? installmentNotes,
  }) async {
    final normalized = newStatus.trim().toLowerCase();
    if (!['paid', 'partial', 'unpaid'].contains(normalized)) {
      throw InvalidPaymentStatusException.invalidStatus(newStatus);
    }

    try {
      final callable = _functionsAsia.httpsCallable('updatePaymentStatus');
      final payload = <String, dynamic>{
        'paymentId': paymentId.trim(),
        'newStatus': normalized,
      };
      if (installmentAmount != null) {
        payload['installmentAmount'] = installmentAmount;
      }
      if (installmentMethod != null) {
        payload['installmentMethod'] = installmentMethod;
      }
      if (installmentNotes != null) {
        payload['installmentNotes'] = installmentNotes;
      }
      await callable.call(payload);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw InvalidPaymentContextException.noOwnership();
      }
      if (e.code == 'not-found') {
        throw PaymentStorageException.notFound();
      }
      if (e.code == 'invalid-argument' || e.code == 'failed-precondition') {
        throw InvalidPaymentStatusException.invalidStatus(
          e.message ?? 'invalid',
        );
      }
      throw PaymentStorageException.update(null);
    }
  }

  Future<String> recordRazorpayPayment({
    required String tenantId,
    required String propertyId,
    required int amount,
    required String transactionId,
    required String orderId,
    required String signature,
    DateTime? paymentDate,
    String? notes,
  }) async {
    final paymentId = await addPayment(
      tenantId: tenantId,
      propertyId: propertyId,
      amount: amount,
      date: paymentDate ?? DateTime.now(),
      method: 'razorpay',
      status: 'pending',
      transactionId: transactionId,
      notes: notes,
    );

    try {
      final verifyCallable = _functionsUs.httpsCallable('verifyPayment');
      await verifyCallable.call({
        'paymentId': paymentId,
        'razorpayPaymentId': transactionId.trim(),
        'razorpayOrderId': orderId.trim(),
        'razorpaySignature': signature.trim(),
      });
      return paymentId;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw PaymentGatewayException(
          message: 'Payment signature verification failed',
        );
      }
      throw PaymentGatewayException(
        message: e.message ?? 'Unable to verify Razorpay payment',
      );
    }
  }

  String _buildIdempotencyKey({
    required String actorUid,
    required String tenantId,
    required String propertyId,
    required int amount,
    required String method,
    DateTime? date,
    String? nonce,
  }) {
    final normalizedDate =
        date?.toUtc().toIso8601String() ??
        DateTime.now().toUtc().toIso8601String();
    final normalizedNonce = (nonce ?? '').trim();
    return [
      'v1',
      actorUid,
      tenantId,
      propertyId,
      amount.toString(),
      method.toLowerCase(),
      normalizedDate,
      normalizedNonce,
    ].join('_');
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
