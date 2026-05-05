import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rentdone/app/app_theme.dart';

enum BackHandlerMode { normal, rootConfirmExit, sensitive }

class BackHandler extends StatefulWidget {
  const BackHandler({
    super.key,
    required this.child,
    required this.mode,
    this.isCriticalInProgress = false,
    this.dialogTitle,
    this.dialogMessage,
    this.confirmText,
    this.cancelText,
    this.useRootNavigatorForDialogs = true,
    this.useRootNavigatorForPop = false,
    this.onRootExitConfirmed,
  });

  final Widget child;
  final BackHandlerMode mode;

  /// Used for sensitive mode to guard flows like payment submission.
  final bool isCriticalInProgress;

  final String? dialogTitle;
  final String? dialogMessage;
  final String? confirmText;
  final String? cancelText;

  final bool useRootNavigatorForDialogs;
  final bool useRootNavigatorForPop;

  final VoidCallback? onRootExitConfirmed;

  const BackHandler.normal({Key? key, required Widget child})
    : this(key: key, child: child, mode: BackHandlerMode.normal);

  const BackHandler.root({
    Key? key,
    required Widget child,
    String? dialogTitle,
    String? dialogMessage,
    String? confirmText,
    String? cancelText,
    VoidCallback? onRootExitConfirmed,
  }) : this(
         key: key,
         child: child,
         mode: BackHandlerMode.rootConfirmExit,
         dialogTitle: dialogTitle,
         dialogMessage: dialogMessage,
         confirmText: confirmText,
         cancelText: cancelText,
         onRootExitConfirmed: onRootExitConfirmed,
       );

  const BackHandler.sensitive({
    Key? key,
    required Widget child,
    required bool isCriticalInProgress,
    String? dialogTitle,
    String? dialogMessage,
    String? confirmText,
    String? cancelText,
  }) : this(
         key: key,
         child: child,
         mode: BackHandlerMode.sensitive,
         isCriticalInProgress: isCriticalInProgress,
         dialogTitle: dialogTitle,
         dialogMessage: dialogMessage,
         confirmText: confirmText,
         cancelText: cancelText,
       );

  @override
  State<BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends State<BackHandler> {
  bool _isHandlingBack = false;
  bool _isDialogOpen = false;

  Future<void> _handleBackPressed() async {
    if (_isHandlingBack || _isDialogOpen) return;

    _isHandlingBack = true;
    try {
      final navigator = Navigator.of(
        context,
        rootNavigator: widget.useRootNavigatorForPop,
      );
      final canPop = navigator.canPop();

      switch (widget.mode) {
        case BackHandlerMode.normal:
          if (canPop) {
            await navigator.maybePop();
          }
          break;

        case BackHandlerMode.rootConfirmExit:
          if (canPop) {
            if (kDebugMode) {
              debugPrint('[BackHandler] rootConfirmExit: local navigator pop');
            }
            await navigator.maybePop();
            break;
          }

          // Shell/nested navigators can report no local history while the
          // root navigator still has pages to pop.
          final rootNavigator = Navigator.of(context, rootNavigator: true);
          if (rootNavigator.canPop()) {
            if (kDebugMode) {
              debugPrint('[BackHandler] rootConfirmExit: root navigator pop');
            }
            await rootNavigator.maybePop();
            break;
          }

          if (kDebugMode) {
            debugPrint(
              '[BackHandler] rootConfirmExit: at app root, prompting exit',
            );
          }

          final shouldExit = await _showLiquidConfirmationDialog(
            title: widget.dialogTitle ?? 'Exit App',
            message: widget.dialogMessage ?? 'Are you sure you want to exit?',
            confirmText: widget.confirmText ?? 'Exit',
            cancelText: widget.cancelText ?? 'Cancel',
          );
          if (!shouldExit) break;

          widget.onRootExitConfirmed?.call();
          if (kDebugMode) {
            debugPrint(
              '[BackHandler] rootConfirmExit: exit confirmed, closing app',
            );
          }
          await SystemNavigator.pop();
          break;

        case BackHandlerMode.sensitive:
          if (widget.isCriticalInProgress) {
            final shouldContinue = await _showLiquidConfirmationDialog(
              title: widget.dialogTitle ?? 'Leave This Screen?',
              message:
                  widget.dialogMessage ??
                  'Going back may interrupt the process. Continue?',
              confirmText: widget.confirmText ?? 'Continue',
              cancelText: widget.cancelText ?? 'Stay',
            );
            if (shouldContinue && canPop) {
              await navigator.maybePop();
            }
            break;
          }

          if (canPop) {
            await navigator.maybePop();
          }
          break;
      }
    } finally {
      _isHandlingBack = false;
    }
  }

  Future<bool> _showLiquidConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
  }) async {
    _isDialogOpen = true;
    try {
      final result =
          await showGeneralDialog<bool>(
            context: context,
            useRootNavigator: widget.useRootNavigatorForDialogs,
            barrierDismissible: false,
            barrierLabel: 'confirm_back_action',
            barrierColor: AppColors.black.withValues(alpha: 0.30),
            transitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (ctx, _, _) {
              return _LiquidConfirmDialog(
                title: title,
                message: message,
                confirmText: confirmText,
                cancelText: cancelText,
              );
            },
            transitionBuilder: (ctx, animation, _, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );

              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
                  child: child,
                ),
              );
            },
          ) ??
          false;
      return result;
    } finally {
      _isDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: widget.child,
    );
  }
}

class _LiquidConfirmDialog extends StatelessWidget {
  const _LiquidConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final primary = OwnerDashboardColors.brandPrimary(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (isDark ? AppTheme.darkCard : AppTheme.lightCard)
                          .withValues(alpha: isDark ? 0.88 : 0.90),
                      primary.withValues(alpha: isDark ? 0.18 : 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: primary.withValues(alpha: isDark ? 0.40 : 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(
                        alpha: isDark ? 0.28 : 0.10,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: OwnerDashboardColors.textPrimary(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OwnerDashboardColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(cancelText),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                          ),
                          child: Text(confirmText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
