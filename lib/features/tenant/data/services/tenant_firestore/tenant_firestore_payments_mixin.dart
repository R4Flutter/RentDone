import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';

import 'tenant_payment_watch_store.dart';
import 'tenant_payment_write_store.dart';

mixin TenantFirestorePaymentsMixin {
  FirebaseFirestore get firestore;

  Stream<TenantPayment?> watchCurrentMonthPayment(String tenantId) =>
      TenantPaymentWatchStore(firestore).watchCurrentMonthPayment(tenantId);

  Future<void> markPaymentAsPaid({
    required String tenantId,
    required int amountPaid,
    required DateTime paymentDate,
    required String paymentMethod,
    required int monthlyRent,
  }) => TenantPaymentWriteStore(firestore).markPaid(
    tenantId: tenantId,
    amountPaid: amountPaid,
    paymentDate: paymentDate,
    paymentMethod: paymentMethod,
    monthlyRent: monthlyRent,
  );

  Future<bool> isPaymentMarked(String tenantId, DateTime date) =>
      TenantPaymentWriteStore(firestore).isMarked(tenantId, date);
}
