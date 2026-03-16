import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';

class TenantPaymentHistoryPage {
  const TenantPaymentHistoryPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<TenantPaymentRecord> items;
  final bool hasMore;
  final DateTime? nextCursor;
}
