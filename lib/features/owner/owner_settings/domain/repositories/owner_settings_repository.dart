import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';

abstract class OwnerSettingsRepository {
  Future<OwnerSettings> getSettings();

  Future<void> saveSettings(OwnerSettings settings);
}
