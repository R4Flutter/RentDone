import 'package:cloud_firestore/cloud_firestore.dart';

class TenantPayment {
  final String id;
  final int amount;
  final String month;
  final String paymentMonth;
  final DateTime? paidDate;
  final String paymentMethod;
  final String status;

  const TenantPayment({
    required this.id,
    required this.amount,
    required this.month,
    required this.paymentMonth,
    this.paidDate,
    required this.paymentMethod,
    required this.status,
  });

  bool get isPaid => status.toLowerCase() == 'paid';

  factory TenantPayment.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return TenantPayment(
      id: doc.id,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      month: data['month'] as String? ?? '',
      paymentMonth: data['paymentMonth'] as String? ?? currentMonthKey,
      paidDate: (data['paidDate'] as Timestamp?)?.toDate(),
      paymentMethod: data['paymentMethod'] as String? ?? 'UPI',
      status: data['status'] as String? ?? 'paid',
    );
  }

  factory TenantPayment.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return TenantPayment(
      id: doc.id,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      month: data['month'] as String? ?? '',
      paymentMonth: data['paymentMonth'] as String? ?? currentMonthKey,
      paidDate: (data['paidDate'] as Timestamp?)?.toDate(),
      paymentMethod: data['paymentMethod'] as String? ?? 'UPI',
      status: data['status'] as String? ?? 'paid',
    );
  }
}
