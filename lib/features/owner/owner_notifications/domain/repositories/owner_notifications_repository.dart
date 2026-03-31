import 'package:rentdone/features/owner/owner_notifications/domain/entities/owner_notification.dart';

abstract class OwnerNotificationsRepository {
  Stream<List<OwnerNotification>> watchRecentNotifications({int limit = 12});
}
