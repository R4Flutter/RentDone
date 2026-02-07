import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class RentDoneApp extends ConsumerWidget {
  const RentDoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // App identity
      title: 'RentDone',

      // Disable debug banner for production
      debugShowCheckedModeBanner: false,

      // THEME (from app_theme.dart)
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // ROUTER (from app_router.dart)
      routerConfig: ref.watch(appRouterProvider),

      // Global builder (safe place for overlays)
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // prevents font scaling bugs
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
