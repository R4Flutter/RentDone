import 'package:rentdone/features/owner/reports/data/models/property_performance_dto.dart';
import 'package:rentdone/features/owner/reports/data/models/report_data_dto.dart';

class ReportsLocalService {
  Future<List<String>> getYearOptions() async {
    return ['2024', '2025', '2026'];
  }

  Future<List<String>> getPropertyOptions() async {
    return ['All Properties', 'Sunshine Residency', 'Palm Heights'];
  }

  Future<ReportDataDto> getReportData({
    required bool isMonthly,
    required String year,
    required String property,
  }) async {
    final seeds = _allSeeds.where((entry) {
      return property == 'All Properties' || entry.name == property;
    }).toList();

    final selectedSeeds = seeds.isEmpty ? _allSeeds : seeds;
    final multiplier = isMonthly ? 1 : 12;

    final totalRevenue =
        selectedSeeds.fold<int>(0, (sum, item) => sum + item.monthlyRevenue) *
        multiplier;
    final totalExpenses =
        selectedSeeds.fold<int>(0, (sum, item) => sum + item.monthlyExpenses) *
        multiplier;
    final totalProfit = totalRevenue - totalExpenses;
    final occupancy =
        selectedSeeds.fold<int>(0, (sum, item) => sum + item.occupancy) /
        selectedSeeds.length;

    return ReportDataDto(
      totalRevenue: 'Rs ${_formatNumber(totalRevenue)}',
      totalRevenueGrowth: isMonthly ? '+12%' : '+10%',
      expenses: 'Rs ${_formatNumber(totalExpenses)}',
      expensesGrowth: isMonthly ? '-3%' : '-2%',
      netProfit: 'Rs ${_formatNumber(totalProfit)}',
      netProfitGrowth: isMonthly ? '+18%' : '+15%',
      occupancyRate: '${occupancy.round()}%',
      occupancyGrowth: isMonthly ? '+5%' : '+4%',
      propertyPerformance: selectedSeeds.map((entry) {
        return PropertyPerformanceDto(
          property: entry.name,
          revenue: 'Rs ${_formatNumber(entry.monthlyRevenue * multiplier)}',
          expenses: 'Rs ${_formatNumber(entry.monthlyExpenses * multiplier)}',
          occupancy: '${entry.occupancy}%',
        );
      }).toList(),
    );
  }

  static const _allSeeds = [
    _PropertySeed(
      name: 'Sunshine Residency',
      monthlyRevenue: 120000,
      monthlyExpenses: 30000,
      occupancy: 90,
    ),
    _PropertySeed(
      name: 'Palm Heights',
      monthlyRevenue: 100000,
      monthlyExpenses: 25000,
      occupancy: 80,
    ),
  ];

  String _formatNumber(int value) {
    final digits = value.abs().toString();
    final chunks = <String>[];

    for (var i = digits.length; i > 0; i -= 3) {
      final start = (i - 3).clamp(0, i);
      chunks.add(digits.substring(start, i));
    }

    final formatted = chunks.reversed.join(',');
    return value < 0 ? '-$formatted' : formatted;
  }
}

class _PropertySeed {
  final String name;
  final int monthlyRevenue;
  final int monthlyExpenses;
  final int occupancy;

  const _PropertySeed({
    required this.name,
    required this.monthlyRevenue,
    required this.monthlyExpenses,
    required this.occupancy,
  });
}
