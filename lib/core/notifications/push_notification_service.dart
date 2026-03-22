import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto/crypto.dart';
import 'package:rentdone/app/app_navigation.dart';

const String _typeRentDue = 'RENT_DUE';
const String _typeRentDueReminder = 'RENT_DUE_REMINDER';
const String _typePaymentReceived = 'PAYMENT_RECEIVED';
const String _typePaymentUpdated = 'PAYMENT_UPDATED';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep background handler lightweight. Navigation is handled when app opens.
}

class PushNotificationService {
  PushNotificationService({
    required FirebaseMessaging messaging,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _messaging = messaging,
       _auth = auth,
       _firestore = firestore;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  String? _lastKnownToken;

  bool _initialized = false;

  String _tokenDocId(String token) {
    return sha256.convert(token.codeUnits).toString();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.setAutoInitEnabled(true);
    await requestPermission();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        return;
      }
      try {
        await _syncCurrentToken(uid: user.uid);
      } catch (error, stackTrace) {
        debugPrint('Push token sync failed on auth change: $error');
        debugPrint('$stackTrace');
      }
    });

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null || token.trim().isEmpty) return;
      try {
        await _saveToken(uid: uid, token: token.trim());
      } catch (error, stackTrace) {
        debugPrint('Push token refresh sync failed: $error');
        debugPrint('$stackTrace');
      }
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      debugPrint('Foreground FCM: ${message.messageId} ${message.data}');
      await _showForegroundNotification(message);
    });

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleTapNavigation,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTapNavigation(initialMessage);
    }

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _syncCurrentToken(uid: uid);
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _initialized = false;
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  Future<void> _syncCurrentToken({required String uid}) async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) return;
    await _saveToken(uid: uid, token: token.trim());
  }

  Future<void> _saveToken({required String uid, required String token}) async {
    final userRef = _firestore.collection('users').doc(uid);
    final tokenRef = userRef.collection('deviceTokens').doc(_tokenDocId(token));
    try {
      await tokenRef.set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_lastKnownToken != null && _lastKnownToken != token) {
        await userRef
            .collection('deviceTokens')
            .doc(_tokenDocId(_lastKnownToken!))
            .delete();
      }

      _lastKnownToken = token;
      return;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;

      // Fallback for environments where deviceTokens rules are not deployed yet.
      await _saveLegacyTokenIfPossible(uid: uid, token: token);
      _lastKnownToken = token;
    }
  }

  Future<void> _saveLegacyTokenIfPossible({
    required String uid,
    required String token,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    try {
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        return;
      }

      await userRef.set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      debugPrint('Legacy token fallback skipped: ${error.code}');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message.notification?.title ?? 'Rent Due Reminder'),
        duration: const Duration(seconds: 2),
      ),
    );

    final tenantId =
        (message.data['tenantId'] ?? message.data['tenant_id'] ?? '')
            .toString()
            .trim();
    if (tenantId.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(message.notification?.title ?? 'Rent Due Reminder'),
          content: Text(
            message.notification?.body ??
                'Rent is due today. Choose an action.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _snoozeReminder(tenantId: tenantId);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Remind Later'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.goNamed(
                  'ownerPayments',
                  queryParameters: {'status': 'unpaid', 'tenantId': tenantId},
                );
              },
              child: const Text('Mark as Paid'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _snoozeReminder({required String tenantId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final snoozeUntil = now.add(const Duration(hours: 4));
    final key = '${tenantId}_${now.year}-${now.month}-${now.day}';

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notificationSnoozes')
          .doc(key)
          .set({
            'tenantId': tenantId,
            'type': _typeRentDue,
            'snoozeUntil': Timestamp.fromDate(snoozeUntil),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      // Snooze is optional UX; ignore permission issues without crashing.
      debugPrint('Snooze save skipped: ${error.code}');
    }
  }

  void _handleTapNavigation(RemoteMessage message) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    final type =
        (message.data['type'] ?? message.data['notification_type'] ?? '')
            .toString()
            .trim();
    final tenantId =
        (message.data['tenantId'] ?? message.data['tenant_id'] ?? '')
            .toString()
            .trim();

    if (type == _typeRentDue || type == _typeRentDueReminder) {
      if (tenantId.isNotEmpty) {
        context.go('/owner/tenants/edit/$tenantId');
        return;
      }
      context.goNamed('ownerPayments', queryParameters: {'status': 'unpaid'});
      return;
    }

    if (type == _typePaymentReceived ||
        type == 'payment_received' ||
        type == _typePaymentUpdated ||
        type == 'payment_updated') {
      final query = <String, String>{'status': 'paid'};
      if (tenantId.isNotEmpty) {
        query['tenantId'] = tenantId;
      }
      context.goNamed('ownerPayments', queryParameters: query);
    }
  }
}
