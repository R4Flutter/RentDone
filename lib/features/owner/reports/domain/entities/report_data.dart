import 'package:rentdone/features/owner/reports/domain/entities/property_performance.dart';

class ReportData {
  final String totalRevenue;
  final String totalRevenueGrowth;
  final String expenses;
  final String expensesGrowth;
  final String netProfit;
  final String netProfitGrowth;
  final String occupancyRate;
  final String occupancyGrowth;
  final List<PropertyPerformance> propertyPerformance;

  const ReportData({
    required this.totalRevenue,
    required this.totalRevenueGrowth,
    required this.expenses,
    required this.expensesGrowth,
    required this.netProfit,
    required this.netProfitGrowth,
    required this.occupancyRate,
    required this.occupancyGrowth,
    required this.propertyPerformance,
  });
}
