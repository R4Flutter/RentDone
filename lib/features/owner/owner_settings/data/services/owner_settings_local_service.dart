import 'package:rentdone/features/owner/owner_settings/data/models/owner_settings_dto.dart';

class OwnerSettingsLocalService {
  OwnerSettingsDto _settings = const OwnerSettingsDto(
    fullName: '',
    email: '',
    phone: '',
    businessName: '',
    gstNumber: '',
    businessAddress: '',
    defaultPaymentMode: '',
    lateFeePercentage: '',
    rentDueDay: '',
    enable2FA: false,
    notificationsEnabled: true,
    darkMode: false,
  );

  OwnerSettingsDto getSettings() {
    return _settings;
  }

  void saveSettings(OwnerSettingsDto settings) {
    _settings = settings;
  }
}
