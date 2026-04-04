import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:rentdone/core/logging/app_logger.dart';

/// Service that activates Firebase App Check for production builds.
///
/// Usage: call `await AppCheckService.activate();` after `Firebase.initializeApp()`.
class AppCheckService {
  AppCheckService._();

  static Future<void> activate() async {
    try {
      await FirebaseAppCheck.instance.activate(
        // For Android, use the Play Integrity provider (default).
        // For iOS, use DeviceCheck or App Attest (default).
        // No custom provider needed for basic usage.
      );
      AppLogger.info('Firebase App Check activated', tag: 'AppCheckService');
    } catch (e, st) {
      // In case App Check cannot be activated (e.g., during local testing),
      // we log the error but do not crash the app.
      AppLogger.error('Failed to activate App Check', error: e, stackTrace: st, tag: 'AppCheckService');
    }
  }
}
