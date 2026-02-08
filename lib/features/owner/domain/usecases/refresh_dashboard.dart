import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// 🔄 Use case: Manual dashboard refresh
/// Pull-to-refresh, retry button, etc.
class RefreshDashboard {
  final DashboardRepository repository;

  const RefreshDashboard(this.repository);

  Future<DashboardSummary> call() async {
    return repository.refreshDashboard();
  }
}