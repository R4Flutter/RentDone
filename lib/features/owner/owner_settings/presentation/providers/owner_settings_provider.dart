import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rentdone/features/owner/owner_settings/di/owner_settings_di.dart';
import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';

@immutable
class OwnerSettingsState {
  final String fullName;
  final String email;
  final String phone;
  final String businessName;
  final String gstNumber;
  final String businessAddress;
  final String defaultPaymentMode;
  final String lateFeePercentage;
  final String rentDueDay;
  final bool enable2FA;
  final bool notificationsEnabled;
  final bool darkMode;
  final String locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final bool isLoading;
  final bool isSaving;
  final bool isFetchingLocation;
  final String? errorMessage;

  const OwnerSettingsState({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.businessName,
    required this.gstNumber,
    required this.businessAddress,
    required this.defaultPaymentMode,
    required this.lateFeePercentage,
    required this.rentDueDay,
    required this.enable2FA,
    required this.notificationsEnabled,
    required this.darkMode,
    required this.locationAddress,
    required this.locationLatitude,
    required this.locationLongitude,
    required this.isLoading,
    required this.isSaving,
    required this.isFetchingLocation,
    required this.errorMessage,
  });

  factory OwnerSettingsState.initial() {
    return const OwnerSettingsState(
      fullName: '',
      email: '',
      phone: '',
      businessName: '',
      gstNumber: '',
      businessAddress: '',
      defaultPaymentMode: 'UPI',
      lateFeePercentage: '0',
      rentDueDay: '5',
      enable2FA: false,
      notificationsEnabled: true,
      darkMode: false,
      locationAddress: '',
      locationLatitude: null,
      locationLongitude: null,
      isLoading: true,
      isSaving: false,
      isFetchingLocation: false,
      errorMessage: null,
    );
  }

  factory OwnerSettingsState.fromEntity(OwnerSettings settings) {
    return OwnerSettingsState(
      fullName: settings.fullName,
      email: settings.email,
      phone: settings.phone,
      businessName: settings.businessName,
      gstNumber: settings.gstNumber,
      businessAddress: settings.businessAddress,
      defaultPaymentMode: settings.defaultPaymentMode,
      lateFeePercentage: settings.lateFeePercentage,
      rentDueDay: settings.rentDueDay,
      enable2FA: settings.enable2FA,
      notificationsEnabled: settings.notificationsEnabled,
      darkMode: settings.darkMode,
      locationAddress: settings.locationAddress,
      locationLatitude: settings.locationLatitude,
      locationLongitude: settings.locationLongitude,
      isLoading: false,
      isSaving: false,
      isFetchingLocation: false,
      errorMessage: null,
    );
  }

  OwnerSettings toEntity() {
    return OwnerSettings(
      fullName: fullName,
      email: email,
      phone: phone,
      businessName: businessName,
      gstNumber: gstNumber,
      businessAddress: businessAddress,
      defaultPaymentMode: defaultPaymentMode,
      lateFeePercentage: lateFeePercentage,
      rentDueDay: rentDueDay,
      enable2FA: enable2FA,
      notificationsEnabled: notificationsEnabled,
      darkMode: darkMode,
      locationAddress: locationAddress,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
    );
  }

  OwnerSettingsState copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? businessName,
    String? gstNumber,
    String? businessAddress,
    String? defaultPaymentMode,
    String? lateFeePercentage,
    String? rentDueDay,
    bool? enable2FA,
    bool? notificationsEnabled,
    bool? darkMode,
    String? locationAddress,
    double? locationLatitude,
    bool clearLocationLatitude = false,
    double? locationLongitude,
    bool clearLocationLongitude = false,
    bool? isLoading,
    bool? isSaving,
    bool? isFetchingLocation,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OwnerSettingsState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      gstNumber: gstNumber ?? this.gstNumber,
      businessAddress: businessAddress ?? this.businessAddress,
      defaultPaymentMode: defaultPaymentMode ?? this.defaultPaymentMode,
      lateFeePercentage: lateFeePercentage ?? this.lateFeePercentage,
      rentDueDay: rentDueDay ?? this.rentDueDay,
      enable2FA: enable2FA ?? this.enable2FA,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
      locationAddress: locationAddress ?? this.locationAddress,
      locationLatitude: clearLocationLatitude
          ? null
          : locationLatitude ?? this.locationLatitude,
      locationLongitude: clearLocationLongitude
          ? null
          : locationLongitude ?? this.locationLongitude,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isFetchingLocation: isFetchingLocation ?? this.isFetchingLocation,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class OwnerSettingsNotifier extends Notifier<OwnerSettingsState> {
  @override
  OwnerSettingsState build() {
    Future.microtask(load);
    return OwnerSettingsState.initial();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final settings = await ref.read(getOwnerSettingsUseCaseProvider).call();
      state = OwnerSettingsState.fromEntity(settings);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load settings. Please try again.',
      );
    }
  }

  void updateFullName(String value) =>
      _update(state.copyWith(fullName: value), persist: true);
  void updateEmail(String value) =>
      _update(state.copyWith(email: value), persist: true);
  void updatePhone(String value) =>
      _update(state.copyWith(phone: value), persist: true);
  void updateBusinessName(String value) =>
      _update(state.copyWith(businessName: value), persist: true);
  void updateGstNumber(String value) =>
      _update(state.copyWith(gstNumber: value), persist: true);
  void updateBusinessAddress(String value) =>
      _update(state.copyWith(businessAddress: value), persist: true);
  void updateDefaultPaymentMode(String value) =>
      _update(state.copyWith(defaultPaymentMode: value), persist: true);
  void updateLateFeePercentage(String value) =>
      _update(state.copyWith(lateFeePercentage: value), persist: true);
  void updateRentDueDay(String value) =>
      _update(state.copyWith(rentDueDay: value), persist: true);
  void setEnable2FA(bool value) =>
      _update(state.copyWith(enable2FA: value), persist: true);
  void setNotificationsEnabled(bool value) =>
      _update(state.copyWith(notificationsEnabled: value), persist: true);
  void setDarkMode(bool value) =>
      _update(state.copyWith(darkMode: value), persist: true);

  Future<void> captureCurrentLocation() async {
    state = state.copyWith(isFetchingLocation: true, clearError: true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Location service is disabled on this device.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw StateError(
          'Location permission denied. Please allow location access.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is permanently denied. Enable it from app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String resolvedAddress = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final addressParts = <String>[
            place.street ?? '',
            place.subLocality ?? '',
            place.locality ?? '',
            place.administrativeArea ?? '',
            place.postalCode ?? '',
            place.country ?? '',
          ].where((value) => value.trim().isNotEmpty).toList();
          resolvedAddress = addressParts.join(', ');
        }
      } catch (_) {}

      if (resolvedAddress.isEmpty) {
        resolvedAddress =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }

      state = state.copyWith(
        isFetchingLocation: false,
        locationAddress: resolvedAddress,
        locationLatitude: position.latitude,
        locationLongitude: position.longitude,
        clearError: true,
      );

      await _persistState();
    } catch (error) {
      state = state.copyWith(
        isFetchingLocation: false,
        errorMessage: _friendlyLocationError(error),
      );
    }
  }

  String _friendlyLocationError(Object error) {
    final raw = error.toString();
    if (error is StateError) {
      return error.message;
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    return raw;
  }

  Future<void> openLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (!opened) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  void _update(OwnerSettingsState next, {required bool persist}) {
    state = next.copyWith(clearError: true);
    if (!persist) return;
    Future.microtask(() async {
      await _persistState();
    });
  }

  Future<void> _persistState() async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(saveOwnerSettingsUseCaseProvider).call(state.toEntity());
      state = state.copyWith(isSaving: false, clearError: true);
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Unable to save settings. Check internet and retry.',
      );
    }
  }
}

final ownerSettingsProvider =
    NotifierProvider<OwnerSettingsNotifier, OwnerSettingsState>(
      OwnerSettingsNotifier.new,
    );
