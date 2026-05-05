import 'package:rentdone/features/owner/owner_payment/domain/entities/tenant_payment_record.dart';

class TenantPaymentHistoryPage {
  const TenantPaymentHistoryPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<TenantPaymentRecord> items;
  final bool hasMore;
  final Object? nextCursor;
}
