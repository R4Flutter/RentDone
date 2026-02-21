import 'package:rentdone/features/owner/reports/data/models/property_performance_dto.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';

class ReportDataDto {
  final String totalRevenue;
  final String totalRevenueGrowth;
  final String expenses;
  final String expensesGrowth;
  final String netProfit;
  final String netProfitGrowth;
  final String occupancyRate;
  final String occupancyGrowth;
  final List<PropertyPerformanceDto> propertyPerformance;

  const ReportDataDto({
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

  ReportData toEntity() {
    return ReportData(
      totalRevenue: totalRevenue,
      totalRevenueGrowth: totalRevenueGrowth,
      expenses: expenses,
      expensesGrowth: expensesGrowth,
      netProfit: netProfit,
      netProfitGrowth: netProfitGrowth,
      occupancyRate: occupancyRate,
      occupancyGrowth: occupancyGrowth,
      propertyPerformance: propertyPerformance
          .map((entry) => entry.toEntity())
          .toList(),
    );
  }
}
