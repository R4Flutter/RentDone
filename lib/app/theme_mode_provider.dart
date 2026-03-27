import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:rentdone/features/auth/di/auth_di.dart';

class AppThemeModeNotifier extends Notifier<ThemeMode?> {
  @override
  ThemeMode? build() => null;

  void setDarkMode(bool enabled) {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void clearOverride() {
    state = null;
  }
}

final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode?>(
  AppThemeModeNotifier.new,
);

final persistedUserThemeModeProvider = StreamProvider<ThemeMode?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final uid = auth.currentUser?.uid;
  if (uid == null || uid.trim().isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid.trim())
      .snapshots()
      .map((doc) {
        final data = doc.data() ?? const <String, dynamic>{};
        final role = (data['role'] as String? ?? '').trim().toLowerCase();

        bool? resolveTenantDarkMode() {
          final settings = data['tenantSettings'];
          if (settings is Map<String, dynamic>) {
            final value = settings['darkAppearanceEnabled'];
            if (value is bool) {
              return value;
            }
          }
          return data['darkMode'] as bool?;
        }

        final bool? darkEnabled = role == 'tenant'
            ? resolveTenantDarkMode()
            : (data['darkMode'] as bool?);

        if (darkEnabled == null) {
          return ThemeMode.light;
        }
        return darkEnabled ? ThemeMode.dark : ThemeMode.light;
      });
});
