import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/tenant/payment_module/models/payment_summary_model.dart';
import 'package:rentdone/features/tenant/payment_module/models/tenant_model.dart';
import 'package:rentdone/features/tenant/payment_module/services/payment_service.dart';
import 'package:rentdone/features/tenant/payment_module/services/razorpay_service.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(firestore: ref.watch(firestoreProvider));
});

final tenantStreamProvider = StreamProvider.family<TenantModel?, String>((
  ref,
  tenantId,
) {
  return ref.watch(paymentServiceProvider).watchTenant(tenantId);
});

final paymentSummaryProvider =
    StreamProvider.family<PaymentSummaryModel, String>((ref, tenantId) {
      return ref
          .watch(paymentServiceProvider)
          .watchCurrentMonthSummary(tenantId);
    });

final dueProvider = FutureProvider.family<double, String>((ref, tenantId) {
  return ref.watch(paymentServiceProvider).calculateDue(tenantId);
});

final tenantModuleRazorpayServiceProvider =
    Provider.autoDispose<RazorpayService>((ref) {
      final service = RazorpayService(
        paymentService: ref.watch(paymentServiceProvider),
      );
      ref.onDispose(service.dispose);
      return service;
    });
