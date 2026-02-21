import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owner_payment/data/models/payment_dto.dart';

class PaymentFirebaseService {
  final FirebaseFirestore _firestore;

  PaymentFirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<PaymentDto>> watchPayments() {
    return _firestore
        .collection('payments')
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PaymentDto.fromFirestore(doc.id, doc.data());
          }).toList();
        });
  }

  Future<void> markPaymentPaidCash(String paymentId) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': 'paid',
      'method': 'cash',
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPaymentPaidOnline(
    String paymentId, {
    String? transactionId,
  }) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': 'paid',
      'method': 'online',
      'transactionId': transactionId,
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
