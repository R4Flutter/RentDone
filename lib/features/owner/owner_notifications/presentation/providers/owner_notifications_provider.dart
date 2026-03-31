import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_notifications/di/owner_notifications_di.dart';
import 'package:rentdone/features/owner/owner_notifications/domain/entities/owner_notification.dart';

final ownerNotificationsProvider = StreamProvider<List<OwnerNotification>>((
  ref,
) {
  final useCase = ref.watch(watchOwnerNotificationsUseCaseProvider);
  return useCase(limit: 12);
});
