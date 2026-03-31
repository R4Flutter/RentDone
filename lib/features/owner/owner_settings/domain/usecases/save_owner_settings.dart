import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';
import 'package:rentdone/features/owner/owner_settings/domain/repositories/owner_settings_repository.dart';

class SaveOwnerSettings {
  final OwnerSettingsRepository _repository;

  const SaveOwnerSettings(this._repository);

  Future<void> call(OwnerSettings settings) {
    return _repository.saveSettings(settings);
  }
}
