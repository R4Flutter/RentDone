import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/core/logging/app_logger.dart';

/// Describes the current connectivity state of the device.
enum ConnectivityStatus {
  /// Device has internet access.
  connected,

  /// Device has no internet access.
  disconnected,

  /// Initial state before status is determined.
  unknown,
}

/// Reactive connectivity monitor exposed as a Riverpod provider.
///
/// Usage in a widget:
/// ```dart
/// final status = ref.watch(connectivityProvider);
/// if (status == ConnectivityStatus.disconnected) {
///   // show offline banner
/// }
/// ```
final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
      ConnectivityNotifier.new,
    );

/// Notifier that listens to the device's connectivity changes.
class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  @override
  ConnectivityStatus build() {
    ref.onDispose(() {
      _isDisposed = true;
      _subscription?.cancel();
    });
    _init();
    return ConnectivityStatus.unknown;
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  var _isDisposed = false;

  void _init() {
    // Get initial status
    _connectivity.checkConnectivity().then(_handleResults).catchError((_) {
      if (!_isDisposed) state = ConnectivityStatus.unknown;
    });

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleResults,
      onError: (_) {
        if (!_isDisposed) state = ConnectivityStatus.unknown;
      },
    );
  }

  void _handleResults(List<ConnectivityResult> results) {
    if (_isDisposed) return;

    final hasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );

    final newStatus = hasConnection
        ? ConnectivityStatus.connected
        : ConnectivityStatus.disconnected;

    if (newStatus != state) {
      state = newStatus;
      AppLogger.info(
        'Connectivity changed: $newStatus',
        tag: 'ConnectivityNotifier',
      );
    }
  }
}
