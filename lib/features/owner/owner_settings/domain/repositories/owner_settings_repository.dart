import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';

abstract class OwnerSettingsRepository {
  OwnerSettings getSettings();

  void saveSettings(OwnerSettings settings);
}
