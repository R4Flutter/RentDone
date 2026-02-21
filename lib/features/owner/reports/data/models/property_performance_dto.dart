import 'package:rentdone/features/owner/reports/domain/entities/property_performance.dart';

class PropertyPerformanceDto {
  final String property;
  final String revenue;
  final String expenses;
  final String occupancy;

  const PropertyPerformanceDto({
    required this.property,
    required this.revenue,
    required this.expenses,
    required this.occupancy,
  });

  PropertyPerformance toEntity() {
    return PropertyPerformance(
      property: property,
      revenue: revenue,
      expenses: expenses,
      occupancy: occupancy,
    );
  }
}
