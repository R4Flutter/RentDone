import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';
import 'package:rentdone/features/owner/owner_settings/domain/repositories/owner_settings_repository.dart';

class GetOwnerSettings {
  final OwnerSettingsRepository _repository;

  const GetOwnerSettings(this._repository);

  Future<OwnerSettings> call() {
    return _repository.getSettings();
  }
}
