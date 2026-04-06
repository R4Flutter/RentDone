import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rentdone/core/security/app_check_service.dart';

import 'package:rentdone/app/app.dart';
import 'package:rentdone/core/ads/admob_config.dart';
import 'package:rentdone/core/notifications/push_notification_service.dart';
import 'package:rentdone/core/logging/app_logger.dart';
import 'package:rentdone/firebase/firebase_options.dart';

/// Global Firebase Analytics instance for app-wide tracking
final firebaseAnalytics = FirebaseAnalytics.instance;

/// Global Firebase Crashlytics instance for error tracking
final firebaseCrashlytics = FirebaseCrashlytics.instance;

/// ------------------------------------------------------------
/// ENTRY POINT
/// ------------------------------------------------------------
Future<void> main() async {
  // Ensures binding is initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (single responsibility)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Activate Firebase App Check for production protection
  await AppCheckService.activate();

  // Optional local Firebase emulator mode for Spark/testing environments.
  await _initializeFirebaseEmulatorsIfEnabled();

  // Enable Firestore offline persistence for seamless offline-first UX.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  AppLogger.info('Firestore offline persistence enabled', tag: 'main');

  // Initialize Crashlytics for error tracking
  await _initializeCrashlytics();

  // Initialize Analytics for user tracking (production only)
  await _initializeAnalytics();

  // Initialize Push Notifications
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize AdMob only on supported mobile platforms.
  await _initializeAdMob();

  AppLogger.info('App initialization complete', tag: 'main');

  // Run the app with Riverpod scope
  runApp(const ProviderScope(child: RentDoneApp()));
}

Future<void> _initializeAdMob() async {
  try {
    if (!AdMobConfig.isSupportedPlatform) return;
    AdMobConfig.enforceProductionGuardrails();
    await MobileAds.instance.initialize();
    AppLogger.info('AdMob initialized', tag: 'main');
  } catch (e, st) {
    AppLogger.error('Failed to initialize AdMob: $e', error: e, stackTrace: st);
  }
}

Future<void> _initializeFirebaseEmulatorsIfEnabled() async {
  const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  const useFunctionsEmulator = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: false,
  );

  const useAuthEmulator = bool.fromEnvironment(
    'USE_AUTH_EMULATOR',
    defaultValue: false,
  );

  const useFirestoreEmulator = bool.fromEnvironment(
    'USE_FIRESTORE_EMULATOR',
    defaultValue: false,
  );

  const host = String.fromEnvironment(
    'FUNCTIONS_EMULATOR_HOST',
    defaultValue: emulatorHost,
  );

  const port = int.fromEnvironment(
    'FUNCTIONS_EMULATOR_PORT',
    defaultValue: 5001,
  );

  const authPort = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );

  const firestorePort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );

  if (useAuthEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    AppLogger.warning(
      'Using Firebase Auth emulator at $host:$authPort',
      tag: 'main',
    );
  }

  if (useFirestoreEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    AppLogger.warning(
      'Using Firestore emulator at $host:$firestorePort',
      tag: 'main',
    );
  }

  if (!useFunctionsEmulator) {
    return;
  }

  FirebaseFunctions.instance.useFunctionsEmulator(host, port);
  AppLogger.warning(
    'Using Firebase Functions emulator at $host:$port',
    tag: 'main',
  );
}

/// Initialize Crashlytics for error and exception tracking
Future<void> _initializeCrashlytics() async {
  try {
    // Only enable Crashlytics in production builds
    if (!kDebugMode) {
      // Pass all uncaught exceptions to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      };

      // Pass all uncaught platform exceptions to Crashlytics
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // Enable collection by default
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } else {
      // Disable Crashlytics in debug mode for cleaner logs
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }

    AppLogger.info('Crashlytics initialized', tag: 'main');
  } catch (e, st) {
    AppLogger.error(
      'Failed to initialize Crashlytics: $e',
      error: e,
      stackTrace: st,
    );
  }
}

/// Initialize Firebase Analytics for user action tracking
Future<void> _initializeAnalytics() async {
  try {
    // Only enable Analytics in production builds
    if (!kDebugMode) {
      // Enable collection by default
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

      // Disable debug events to reduce noise
      // Debug events increase cost without providing value
    } else {
      // Disable Analytics in debug mode to avoid polluting data
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    }

    AppLogger.info('Firebase Analytics initialized', tag: 'main');
  } catch (e, st) {
    AppLogger.error(
      'Failed to initialize Firebase Analytics: $e',
      error: e,
      stackTrace: st,
    );
  }
}
