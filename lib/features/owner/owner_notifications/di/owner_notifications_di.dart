import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_notifications/data/repositories/owner_notifications_repository_impl.dart';
import 'package:rentdone/features/owner/owner_notifications/data/services/owner_notifications_firebase_service.dart';
import 'package:rentdone/features/owner/owner_notifications/domain/repositories/owner_notifications_repository.dart';
import 'package:rentdone/features/owner/owner_notifications/domain/usecases/watch_owner_notifications.dart';

final ownerNotificationsFirebaseServiceProvider =
    Provider<OwnerNotificationsFirebaseService>((ref) {
      return OwnerNotificationsFirebaseService();
    });

final ownerNotificationsRepositoryProvider =
    Provider<OwnerNotificationsRepository>((ref) {
      final service = ref.watch(ownerNotificationsFirebaseServiceProvider);
      return OwnerNotificationsRepositoryImpl(service);
    });

final watchOwnerNotificationsUseCaseProvider =
    Provider<WatchOwnerNotifications>((ref) {
      final repository = ref.watch(ownerNotificationsRepositoryProvider);
      return WatchOwnerNotifications(repository);
    });
