import 'package:rentdone/features/tenant/data/models/payment_record_model.dart';
import 'package:rentdone/features/tenant/data/models/tenant_model.dart';

class PaymentSummaryModel {
  const PaymentSummaryModel({
    required this.tenant,
    required this.currentMonthSuccessfulPayments,
    required this.totalPaidThisMonth,
    required this.dueAmount,
  });

  final TenantModel? tenant;
  final List<PaymentRecordModel> currentMonthSuccessfulPayments;
  final double totalPaidThisMonth;
  final double dueAmount;

  bool get hasTenantData => tenant != null;
}
