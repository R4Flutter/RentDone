import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';



class DashboardSummaryDto {
  final Map<String, dynamic> json;

  DashboardSummaryDto(this.json);

  DashboardSummary toEntity() {
    return DashboardSummary(
      totalProperties: json['totalProperties'] ?? 0,
      vacantProperties: json['vacantProperties'] ?? 0,
      collectedAmount: json['collectedAmount'] ?? 0,
      collectedPayments: json['collectedPayments'] ?? 0,
      pendingAmount: json['pendingAmount'] ?? 0,
      pendingPayments: json['pendingPayments'] ?? 0,
      cashAmount: json['cashAmount'] ?? 0,
      onlineAmount: json['onlineAmount'] ?? 0,
    );
  }
}