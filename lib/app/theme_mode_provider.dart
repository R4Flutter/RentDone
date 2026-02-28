import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
