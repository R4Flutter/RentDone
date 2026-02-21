import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_settings/data/models/owner_settings_dto.dart';

class OwnerSettingsFirestoreService {
  OwnerSettingsFirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<OwnerSettingsDto> getSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      return _defaultSettings();
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? const <String, dynamic>{};

    double? toDouble(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final geoPoint = data['location'] is GeoPoint
        ? data['location'] as GeoPoint
        : null;
    final latitude = toDouble(data['locationLatitude']) ?? geoPoint?.latitude;
    final longitude =
        toDouble(data['locationLongitude']) ?? geoPoint?.longitude;

    return OwnerSettingsDto(
      fullName: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      businessName: (data['businessName'] as String?) ?? '',
      gstNumber: (data['gstNumber'] as String?) ?? '',
      businessAddress: (data['businessAddress'] as String?) ?? '',
      defaultPaymentMode: (data['defaultPaymentMode'] as String?) ?? 'UPI',
      lateFeePercentage: (data['lateFeePercentage'] as String?) ?? '0',
      rentDueDay: (data['rentDueDay'] as String?) ?? '5',
      enable2FA: (data['enable2FA'] as bool?) ?? false,
      notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
      darkMode: (data['darkMode'] as bool?) ?? false,
      locationAddress: (data['locationAddress'] as String?) ?? '',
      locationLatitude: latitude,
      locationLongitude: longitude,
    );
  }

  Future<void> saveSettings(OwnerSettingsDto settings) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to update settings.');
    }

    final now = FieldValue.serverTimestamp();
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final existing = snapshot.data() ?? const <String, dynamic>{};
    final existingRole = (existing['role'] as String?)?.trim();
    final role = (existingRole == 'owner' || existingRole == 'tenant')
        ? existingRole
        : 'owner';

    final latitude = settings.locationLatitude;
    final longitude = settings.locationLongitude;
    final hasCoordinates = latitude != null && longitude != null;

    final payload = <String, dynamic>{
      'uid': user.uid,
      'role': role,
      'name': settings.fullName.isNotEmpty
          ? settings.fullName
          : (user.displayName ?? ''),
      'email': settings.email.isNotEmpty ? settings.email : (user.email ?? ''),
      'phone': settings.phone,
      'businessName': settings.businessName,
      'gstNumber': settings.gstNumber,
      'businessAddress': settings.businessAddress,
      'defaultPaymentMode': settings.defaultPaymentMode,
      'lateFeePercentage': settings.lateFeePercentage,
      'rentDueDay': settings.rentDueDay,
      'enable2FA': settings.enable2FA,
      'notificationsEnabled': settings.notificationsEnabled,
      'darkMode': settings.darkMode,
      'locationAddress': settings.locationAddress,
      'locationLatitude': latitude,
      'locationLongitude': longitude,
      'updatedAt': now,
      if (!snapshot.exists) 'createdAt': now,
      if (hasCoordinates) 'location': GeoPoint(latitude, longitude),
      if (hasCoordinates) 'locationUpdatedAt': now,
    };

    if (!hasCoordinates) {
      payload['location'] = FieldValue.delete();
      payload['locationUpdatedAt'] = FieldValue.delete();
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  OwnerSettingsDto _defaultSettings() {
    return const OwnerSettingsDto(
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
    );
  }
}
