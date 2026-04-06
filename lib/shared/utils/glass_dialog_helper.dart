import 'package:flutter/material.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

/// Helper for showing glassmorphic dialogs throughout the app
class GlassDialogHelper {
  /// Show a simple confirmation dialog with glassmorphism
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    bool isDangerous = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => GlassDialog(
        title: title,
        content: Text(message, style: TextStyle(color: textColor, height: 1.5)),
        actions: [
          GlassButton(
            onPressed: () => Navigator.pop(ctx, false),
            label: cancelText,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          GlassButton(
            onPressed: () => Navigator.pop(ctx, true),
            label: confirmText,
            isPrimary: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ],
      ),
    );
  }

  /// Show a loading dialog with glassmorphism
  static void showLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
    bool dismissible = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => GlassDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const AppLoadingIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Show an error dialog with glassmorphism
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String actionText = 'OK',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final errorColor = Colors.redAccent;

    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => GlassDialog(
        title: title,
        titleWidget: Row(
          children: [
            Icon(Icons.error_outline, color: errorColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: TextStyle(color: textColor, height: 1.5)),
        actions: [
          GlassButton(
            onPressed: () => Navigator.pop(ctx),
            label: actionText,
            isPrimary: true,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ],
      ),
    );
  }

  /// Show a success dialog with glassmorphism
  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String actionText = 'Done',
    VoidCallback? onDismiss,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final successColor = Colors.green.shade400;

    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => GlassDialog(
        title: title,
        titleWidget: Row(
          children: [
            Icon(Icons.check_circle_outline, color: successColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: TextStyle(color: textColor, height: 1.5)),
        actions: [
          GlassButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDismiss?.call();
            },
            label: actionText,
            isPrimary: true,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ],
      ),
    );
  }

  /// Show a custom dialog with glassmorphism
  static Future<T?> showCustomDialog<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    List<Widget>? actions,
    bool dismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) =>
          GlassDialog(title: title, content: content, actions: actions),
    );
  }

  /// Show a bottom sheet with glassmorphism
  static Future<T?> showCustomBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool showDragHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      isScrollControlled: true,
      builder: (ctx) => GlassBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        child: child,
      ),
    );
  }
}
