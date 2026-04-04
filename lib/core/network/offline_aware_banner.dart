import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/core/network/connectivity_provider.dart';

/// A global banner widget that shows "No internet connection" when
/// the device goes offline.
///
/// Wrap this around your main app content:
/// ```dart
/// OfflineAwareBanner(child: child)
/// ```
class OfflineAwareBanner extends ConsumerWidget {
  const OfflineAwareBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);
    final isOffline = status == ConnectivityStatus.disconnected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Animated offline banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          height: isOffline ? null : 0,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF92400E)
                : const Color(0xFFFBBF24),
          ),
          child: isOffline
              ? SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No internet connection',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Main content
        Expanded(child: child),
      ],
    );
  }
}
