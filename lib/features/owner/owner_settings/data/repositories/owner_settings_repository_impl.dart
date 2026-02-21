import 'package:rentdone/features/owner/owner_settings/data/models/owner_settings_dto.dart';
import 'package:rentdone/features/owner/owner_settings/data/services/owner_settings_local_service.dart';
import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';
import 'package:rentdone/features/owner/owner_settings/domain/repositories/owner_settings_repository.dart';

class OwnerSettingsRepositoryImpl implements OwnerSettingsRepository {
  final OwnerSettingsLocalService _service;

  OwnerSettingsRepositoryImpl(this._service);

  @override
  OwnerSettings getSettings() {
    return _service.getSettings().toEntity();
  }

  @override
  void saveSettings(OwnerSettings settings) {
    _service.saveSettings(OwnerSettingsDto.fromEntity(settings));
  }
}
