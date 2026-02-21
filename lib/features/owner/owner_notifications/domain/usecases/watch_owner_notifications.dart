import 'package:rentdone/features/owner/owner_notifications/domain/entities/owner_notification.dart';
import 'package:rentdone/features/owner/owner_notifications/domain/repositories/owner_notifications_repository.dart';

class WatchOwnerNotifications {
  final OwnerNotificationsRepository _repository;

  const WatchOwnerNotifications(this._repository);

  Stream<List<OwnerNotification>> call({int limit = 12}) {
    return _repository.watchRecentNotifications(limit: limit);
  }
}
