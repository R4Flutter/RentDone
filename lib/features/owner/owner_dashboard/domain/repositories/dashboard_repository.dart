import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import '../entities/dashboard_summary.dart';

/// Contract that data layer MUST implement
abstract class DashboardRepository {
  /// Fetch dashboard summary (properties, payments, etc.)
  Future<DashboardSummary> getDashboardSummary();

  /// Optional: refresh / force reload
  Future<DashboardSummary> refreshDashboard();

  /// Live dashboard updates for responsive UI.
  Stream<DashboardSummary> watchDashboardSummary();

  Stream<List<AppMessage>> watchRecentMessages({int limit = 6});
}
