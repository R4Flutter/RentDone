import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';

mixin TenantDashboardPaymentsMixin {
  TenantFirestoreService get firestoreService;

  Stream<TenantPayment?> watchCurrentMonthPayment(String tenantId) =>
      firestoreService.watchCurrentMonthPayment(tenantId);
  Future<void> markPaymentAsPaid({
    required String tenantId,
    required int amountPaid,
    required DateTime paymentDate,
    required String paymentMethod,
    required int monthlyRent,
  }) => firestoreService.markPaymentAsPaid(
    tenantId: tenantId,
    amountPaid: amountPaid,
    paymentDate: paymentDate,
    paymentMethod: paymentMethod,
    monthlyRent: monthlyRent,
  );
  Future<List<TenantReminder>> getRecentReminders(
    String tenantId, {
    int limit = 5,
  }) => firestoreService.getRecentReminders(tenantId, limit: limit);
}
