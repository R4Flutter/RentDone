import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentInstallment {
  const PaymentInstallment({
    required this.amount,
    required this.date,
    required this.method,
    this.notes,
  });

  final int amount;
  final DateTime date;
  final String method;
  final String? notes;

  factory PaymentInstallment.fromMap(Map<String, dynamic> data) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final method = (data['method'] as String? ?? 'Cash').trim();
    final notes = (data['notes'] as String?)?.trim();

    return PaymentInstallment(
      amount: amount < 0 ? 0 : amount,
      date: toDate(data['date'] ?? data['createdAt']),
      method: method.isEmpty ? 'Cash' : method,
      notes: notes == null || notes.isEmpty ? null : notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'method': method,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}

class TenantPaymentRecord {
  const TenantPaymentRecord({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
    required this.createdAt,
    required this.baseAmount,
    required this.paidAmount,
    required this.remainingAmount,
    this.transactionId,
    this.notes,
    this.installments = const <PaymentInstallment>[],
  });

  final String id;
  final String tenantId;
  final String propertyId;
  final int amount;
  final DateTime date;
  final String method;
  final String status;
  final DateTime createdAt;
  final int baseAmount;
  final int paidAmount;
  final int remainingAmount;
  final String? transactionId;
  final String? notes;
  final List<PaymentInstallment> installments;

  bool get isSettled => remainingAmount <= 0;

  factory TenantPaymentRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime toDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return fallback;
    }

    final createdAt = toDate(
      data['createdAt'] ?? data['updatedAt'] ?? data['paidAt'],
      DateTime.now(),
    );
    final date = toDate(
      data['date'] ??
          data['paymentDate'] ??
          data['paidAt'] ??
          data['paidDate'] ??
          data['dueDate'] ??
          data['createdAt'],
      createdAt,
    );

    String normalizeStatus(String? raw) {
      final value = (raw ?? '').trim().toLowerCase();
      if (value == 'paid' || value == 'success') return 'paid';
      if (value == 'partial') return 'partial';
      return 'unpaid';
    }

    String normalizeMethod(String? raw) {
      final value = (raw ?? '').trim();
      if (value.isEmpty) return 'Cash';
      if (value.toLowerCase() == 'online') return 'UPI';
      return value;
    }

    final rawInstallments =
        (data['installments'] as List<dynamic>? ?? const []);
    final installments = <PaymentInstallment>[];
    for (final raw in rawInstallments) {
      if (raw is Map<String, dynamic>) {
        final parsed = PaymentInstallment.fromMap(raw);
        if (parsed.amount > 0) installments.add(parsed);
      } else if (raw is Map) {
        final normalized = raw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final parsed = PaymentInstallment.fromMap(normalized);
        if (parsed.amount > 0) installments.add(parsed);
      }
    }

    final explicitBase =
        (data['baseAmount'] as num?)?.toInt() ??
        (data['totalAmount'] as num?)?.toInt() ??
        (data['amount'] as num?)?.toInt() ??
        0;
    final explicitPaid = (data['paidAmount'] as num?)?.toInt();

    final fallbackPaidByStatus = (() {
      final status = normalizeStatus(data['status'] as String?);
      if (status == 'paid') return explicitBase;
      if (status == 'partial') {
        return (data['amountPaid'] as num?)?.toInt() ??
            (data['amount'] as num?)?.toInt() ??
            0;
      }
      return 0;
    })();

    final paidFromInstallments = installments.fold<int>(
      0,
      (total, item) => total + item.amount,
    );

    final paidAmount =
        (explicitPaid ??
                (paidFromInstallments > 0
                    ? paidFromInstallments
                    : fallbackPaidByStatus))
            .clamp(0, 1 << 30);

    final baseAmount = explicitBase > paidAmount ? explicitBase : paidAmount;

    final remainingAmount =
        ((data['remainingAmount'] as num?)?.toInt() ??
                (baseAmount - paidAmount))
            .clamp(0, 1 << 30);

    final computedStatus = remainingAmount == 0
        ? (paidAmount > 0 ? 'paid' : 'unpaid')
        : (paidAmount > 0 ? 'partial' : 'unpaid');

    return TenantPaymentRecord(
      id: id,
      tenantId: (data['tenantId'] as String? ?? '').trim(),
      propertyId: (data['propertyId'] as String? ?? '').trim(),
      amount: baseAmount,
      date: date,
      method: normalizeMethod(
        (data['method'] ?? data['paymentMethod'] ?? data['gateway'] ?? 'Cash')
            as String?,
      ),
      status: computedStatus,
      createdAt: createdAt,
      baseAmount: baseAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      transactionId: (data['transactionId'] as String?)?.trim(),
      notes: (data['notes'] as String?)?.trim(),
      installments: installments,
    );
  }

  Map<String, dynamic> toFirestore({required String ownerId}) {
    return {
      'tenantId': tenantId,
      'propertyId': propertyId,
      'ownerId': ownerId,
      'amount': baseAmount,
      'baseAmount': baseAmount,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'date': Timestamp.fromDate(date),
      'method': method,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'installments': installments.map((item) => item.toMap()).toList(),
      'transactionId': transactionId,
      'notes': notes,
    };
  }
}
