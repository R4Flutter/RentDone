import 'package:rentdone/features/owner/owner_payment/data/services/payment_analytics_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_query_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_write_service.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentQueryService queryService;
  final PaymentWriteService writeService;
  final PaymentAnalyticsService analyticsService;

  PaymentRepositoryImpl({
    required this.queryService,
    required this.writeService,
    required this.analyticsService,
  });

  @override
  Stream<List<Payment>> watchPayments() {
    return queryService.watchPayments().map((dtos) {
      return dtos.map((dto) => dto.toEntity()).toList();
    });
  }

  @override
  Future<void> markPaymentPaidCash(String paymentId) {
    return writeService.markPaymentPaidCash(paymentId);
  }

  @override
  Future<void> markPaymentPaidOnline(
    String paymentId, {
    String? transactionId,
  }) {
    return writeService.markPaymentPaidOnline(
      paymentId,
      transactionId: transactionId,
    );
  }
}
