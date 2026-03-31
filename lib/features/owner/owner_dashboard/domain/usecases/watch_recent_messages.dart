import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/dashboard_repository.dart';

class WatchRecentMessages {
  final DashboardRepository _repository;

  const WatchRecentMessages(this._repository);

  Stream<List<AppMessage>> call({int limit = 6}) {
    return _repository.watchRecentMessages(limit: limit);
  }
}
