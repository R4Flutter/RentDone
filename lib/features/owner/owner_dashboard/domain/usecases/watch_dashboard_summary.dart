import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/dashboard_repository.dart';

class WatchDashboardSummary {
  final DashboardRepository _repository;

  const WatchDashboardSummary(this._repository);

  Stream<DashboardSummary> call() {
    return _repository.watchDashboardSummary();
  }
}
