import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// 🎯 Use case: Get dashboard summary
/// Called when dashboard screen loads
class GetDashboardSummary {
  final DashboardRepository repository;

  const GetDashboardSummary(this.repository);

  Future<DashboardSummary> call() async {
    return repository.getDashboardSummary();
  }
}