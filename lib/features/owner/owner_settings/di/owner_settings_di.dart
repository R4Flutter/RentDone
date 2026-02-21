import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_settings/data/repositories/owner_settings_repository_impl.dart';
import 'package:rentdone/features/owner/owner_settings/data/services/owner_settings_local_service.dart';
import 'package:rentdone/features/owner/owner_settings/domain/repositories/owner_settings_repository.dart';
import 'package:rentdone/features/owner/owner_settings/domain/usecases/get_owner_settings.dart';
import 'package:rentdone/features/owner/owner_settings/domain/usecases/save_owner_settings.dart';

final ownerSettingsLocalServiceProvider = Provider<OwnerSettingsLocalService>((
  ref,
) {
  return OwnerSettingsLocalService();
});

final ownerSettingsRepositoryProvider = Provider<OwnerSettingsRepository>((
  ref,
) {
  final service = ref.watch(ownerSettingsLocalServiceProvider);
  return OwnerSettingsRepositoryImpl(service);
});

final getOwnerSettingsUseCaseProvider = Provider<GetOwnerSettings>((ref) {
  return GetOwnerSettings(ref.watch(ownerSettingsRepositoryProvider));
});

final saveOwnerSettingsUseCaseProvider = Provider<SaveOwnerSettings>((ref) {
  return SaveOwnerSettings(ref.watch(ownerSettingsRepositoryProvider));
});
