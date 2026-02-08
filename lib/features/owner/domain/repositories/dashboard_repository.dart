import '../entities/dashboard_summary.dart';

/// Contract that data layer MUST implement
abstract class DashboardRepository {
  /// Fetch dashboard summary (properties, payments, etc.)
  Future<DashboardSummary> getDashboardSummary();

  /// Optional: refresh / force reload
  Future<DashboardSummary> refreshDashboard();
}