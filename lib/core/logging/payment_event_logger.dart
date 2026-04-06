import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class PaymentEventLogger {
  PaymentEventLogger({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
  }) : _analytics = analytics ?? FirebaseAnalytics.instance,
       _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  static final PaymentEventLogger instance = PaymentEventLogger();

  Future<void> logEvent({
    required String event,
    required String? userId,
    required String? tenantId,
    required String? ownerId,
    required String? paymentId,
    required String? idempotencyKey,
    required int? amount,
    required String? method,
    required String? status,
    String? errorCode,
    String? errorMessage,
    String? deviceInfo,
    Map<String, Object?> extra = const {},
  }) async {
    final payload = _buildPayload(
      event: event,
      userId: userId,
      tenantId: tenantId,
      ownerId: ownerId,
      paymentId: paymentId,
      idempotencyKey: idempotencyKey,
      amount: amount,
      method: method,
      status: status,
      errorCode: errorCode,
      errorMessage: errorMessage,
      deviceInfo: deviceInfo,
      extra: extra,
    );

    try {
      await _analytics.logEvent(
        name: _normalizeEventName(event),
        parameters: payload.isEmpty ? null : payload,
      );
    } catch (_) {
      // Analytics logging should never block payment flows.
    }
  }

  Future<void> logError({
    required String event,
    required String? userId,
    required String? tenantId,
    required String? ownerId,
    required String? paymentId,
    required String? idempotencyKey,
    required int? amount,
    required String? method,
    required String? status,
    required String errorCode,
    required String errorMessage,
    Object? error,
    StackTrace? stackTrace,
    String? deviceInfo,
    Map<String, Object?> extra = const {},
  }) async {
    await logEvent(
      event: event,
      userId: userId,
      tenantId: tenantId,
      ownerId: ownerId,
      paymentId: paymentId,
      idempotencyKey: idempotencyKey,
      amount: amount,
      method: method,
      status: status,
      errorCode: errorCode,
      errorMessage: errorMessage,
      deviceInfo: deviceInfo,
      extra: extra,
    );

    try {
      if (!kDebugMode) {
        if (userId != null) {
          await _crashlytics.setCustomKey('userId', userId);
        }
        if (tenantId != null) {
          await _crashlytics.setCustomKey('tenantId', tenantId);
        }
        if (paymentId != null) {
          await _crashlytics.setCustomKey('paymentId', paymentId);
        }
        await _crashlytics.recordError(
          error ?? errorMessage,
          stackTrace,
          reason: event,
          fatal: false,
        );
      }
    } catch (_) {
      // Crashlytics failures should never block payment flows.
    }
  }

  Map<String, Object> _buildPayload({
    required String event,
    required String? userId,
    required String? tenantId,
    required String? ownerId,
    required String? paymentId,
    required String? idempotencyKey,
    required int? amount,
    required String? method,
    required String? status,
    String? errorCode,
    String? errorMessage,
    String? deviceInfo,
    Map<String, Object?> extra = const {},
  }) {
    final payload = <String, Object>{};

    void addValue(String key, Object? value) {
      if (value == null) return;
      payload[key] = value;
    }

    addValue('event', event);
    addValue('timestamp', DateTime.now().toUtc().toIso8601String());
    addValue('userId', _normalize(userId));
    addValue('tenantId', _normalize(tenantId));
    addValue('ownerId', _normalize(ownerId));
    addValue('paymentId', _normalize(paymentId));
    addValue('idempotencyKey', _normalize(idempotencyKey));
    addValue('amount', amount);
    addValue('method', _normalize(method));
    addValue('status', _normalize(status));
    addValue('errorCode', _normalize(errorCode));
    addValue('errorMessage', _normalize(errorMessage));
    addValue('deviceInfo', _normalize(deviceInfo) ?? _deviceInfo());

    extra.forEach((key, value) {
      if (value == null) return;
      if (value is String || value is num || value is bool) {
        payload[key] = value;
      } else {
        payload[key] = value.toString();
      }
    });

    return payload;
  }

  String _normalizeEventName(String event) {
    var normalized = event.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (normalized.isEmpty) {
      normalized = 'payment_event';
    }
    if (normalized.length > 40) {
      normalized = normalized.substring(0, 40);
    }
    return normalized;
  }

  String? _normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _deviceInfo() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
