import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';
import 'package:rentdone/features/owner/owner_settings/domain/repositories/owner_settings_repository.dart';

class SaveOwnerSettings {
  final OwnerSettingsRepository _repository;

  const SaveOwnerSettings(this._repository);

  void call(OwnerSettings settings) {
    _repository.saveSettings(settings);
  }
}
