import 'package:rentdone/features/owner/owner_settings/data/models/owner_settings_dto.dart';
import 'package:rentdone/features/owner/owner_settings/data/services/owner_settings_firestore_service.dart';
import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';
import 'package:rentdone/features/owner/owner_settings/domain/repositories/owner_settings_repository.dart';

class OwnerSettingsRepositoryImpl implements OwnerSettingsRepository {
  final OwnerSettingsFirestoreService _service;

  OwnerSettingsRepositoryImpl(this._service);

  @override
  Future<OwnerSettings> getSettings() async {
    return (await _service.getSettings()).toEntity();
  }

  @override
  Future<void> saveSettings(OwnerSettings settings) {
    return _service.saveSettings(OwnerSettingsDto.fromEntity(settings));
  }
}
