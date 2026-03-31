import 'package:rentdone/features/owner/owner_notifications/data/services/owner_notifications_firebase_service.dart';
import 'package:rentdone/features/owner/owner_notifications/domain/entities/owner_notification.dart';
import 'package:rentdone/features/owner/owner_notifications/domain/repositories/owner_notifications_repository.dart';

class OwnerNotificationsRepositoryImpl implements OwnerNotificationsRepository {
  final OwnerNotificationsFirebaseService _service;

  OwnerNotificationsRepositoryImpl(this._service);

  @override
  Stream<List<OwnerNotification>> watchRecentNotifications({int limit = 12}) {
    return _service
        .watchRecentNotifications(limit: limit)
        .map((items) => items.map((item) => item.toEntity()).toList());
  }
}
