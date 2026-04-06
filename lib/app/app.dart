import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/core/network/offline_aware_banner.dart';
import 'package:rentdone/core/notifications/push_notification_provider.dart';
import 'package:rentdone/app/theme_mode_provider.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

import 'app_router.dart';
import 'app_theme.dart';

/// ------------------------------------------------------------
/// ROOT APPLICATION WIDGET
/// ------------------------------------------------------------
///
/// Responsibilities:
/// - Holds MaterialApp
/// - Injects theme
/// - Injects router
///
/// Must NOT:
/// - Contain business logic
/// - Know about Firebase
/// - Know about authentication
///
class RentDoneApp extends ConsumerStatefulWidget {
  const RentDoneApp({super.key});

  @override
  ConsumerState<RentDoneApp> createState() => _RentDoneAppState();
}

class _RentDoneAppState extends ConsumerState<RentDoneApp> {
  bool _notificationsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notificationsInitialized) return;
    _notificationsInitialized = true;

    Future.microtask(() async {
      await ref.read(pushNotificationServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final persistedThemeAsync = ref.watch(persistedUserThemeModeProvider);
    final themeOverride = ref.watch(appThemeModeProvider);
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;

    final persistedTheme = persistedThemeAsync.maybeWhen(
      data: (mode) => mode ?? ThemeMode.light,
      orElse: () => ThemeMode.system,
    );

    // Keep auth-entry flow (splash, role, login, signup) aligned to system theme.
    final baseThemeMode = currentUser == null
        ? ThemeMode.system
        : persistedTheme;
    final themeMode = themeOverride ?? baseThemeMode;

    return MaterialApp.router(
      // App identity
      title: 'RentDone',

      // Disable debug banner for production
      debugShowCheckedModeBanner: false,

      // THEME (from app_theme.dart)
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // ROUTER (from app_router.dart)
      routerConfig: ref.watch(appRouterProvider),

      // Global builder (safe place for overlays)
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(
              1.0,
            ), // prevents font scaling bugs
          ),
          child: OfflineAwareBanner(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
