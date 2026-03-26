import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:rentdone/app/app.dart';
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

  // Initialize Crashlytics for error tracking
  await _initializeCrashlytics();

  // Initialize Analytics for user tracking (production only)
  await _initializeAnalytics();

  // Initialize Push Notifications
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  AppLogger.info('App initialization complete', tag: 'main');

  // Run the app with Riverpod scope
  runApp(const ProviderScope(child: RentDoneApp()));
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
      PlatformDispatcher.instance.onError = (error, stack) {
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
