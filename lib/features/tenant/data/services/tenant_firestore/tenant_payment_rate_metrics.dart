import 'package:cloud_firestore/cloud_firestore.dart';

class TenantPaymentRateMetrics {
  static ({double onTimeRate, double lateRate}) resolve({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs,
    required int dueDay,
    required int? onTimePayments,
    required int? latePayments,
  }) {
    if (onTimePayments != null && latePayments != null) {
      final total = onTimePayments + latePayments;
      return total <= 0
          ? (onTimeRate: 0, lateRate: 0)
          : _rates(onTimePayments, latePayments, total);
    }

    var onTime = 0;
    var late = 0;
    for (final paymentDoc in paymentDocs) {
      final data = paymentDoc.data();
      final paymentDate =
          (data['paymentDate'] as Timestamp?)?.toDate() ??
          (data['paidDate'] as Timestamp?)?.toDate();
      if (paymentDate == null) continue;
      final dueDate = DateTime(
        paymentDate.year,
        paymentDate.month,
        dueDay.clamp(1, 31).toInt(),
      );
      paymentDate.isAfter(dueDate) ? late++ : onTime++;
    }

    final total = onTime + late;
    return total <= 0
        ? (onTimeRate: 0, lateRate: 0)
        : _rates(onTime, late, total);
  }

  static ({double onTimeRate, double lateRate}) _rates(
    int onTime,
    int late,
    int total,
  ) => (
    onTimeRate: double.parse(((onTime * 100) / total).toStringAsFixed(1)),
    lateRate: double.parse(((late * 100) / total).toStringAsFixed(1)),
  );
}
