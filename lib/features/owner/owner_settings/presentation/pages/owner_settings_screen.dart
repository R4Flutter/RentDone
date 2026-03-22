import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/notifications/push_notification_provider.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(ownerSettingsProvider);
    final notifier = ref.read(ownerSettingsProvider.notifier);
    final isDesktop = MediaQuery.of(context).size.width > 980;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                  context,
                ),
              ),
            ),
          ),
          _liquidBlob(
            context: context,
            top: -80,
            left: -58,
            size: 300,
            isDark: isDark,
          ),
          _liquidBlob(
            context: context,
            bottom: -92,
            right: -60,
            size: 260,
            isDark: isDark,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: _pageHeader(context, theme, settings, notifier),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: notifier.load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 1200 : double.infinity,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (settings.errorMessage != null)
                                _errorBanner(context, settings.errorMessage!),
                              if (settings.errorMessage != null)
                                const SizedBox(height: 14),
                              if (settings.isLoading)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 14),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              if (isDesktop)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _glassSection(
                                        context,
                                        theme,
                                        icon: Icons.shield_outlined,
                                        title: 'Security',
                                        subtitle:
                                            'Protect your account access and session.',
                                        child: _securitySection(
                                          context,
                                          ref,
                                          theme,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _glassSection(
                                        context,
                                        theme,
                                        icon: Icons.tune,
                                        title: 'Preferences',
                                        subtitle:
                                            'Control alerts and display behavior.',
                                        child: _systemSection(
                                          context,
                                          ref,
                                          settings,
                                          notifier,
                                          theme,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _glassSection(
                                  context,
                                  theme,
                                  icon: Icons.shield_outlined,
                                  title: 'Security',
                                  subtitle:
                                      'Protect your account access and session.',
                                  child: _securitySection(context, ref, theme),
                                ),
                                const SizedBox(height: 16),
                                _glassSection(
                                  context,
                                  theme,
                                  icon: Icons.tune,
                                  title: 'Preferences',
                                  subtitle:
                                      'Control alerts and display behavior.',
                                  child: _systemSection(
                                    context,
                                    ref,
                                    settings,
                                    notifier,
                                    theme,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageHeader(
    BuildContext context,
    ThemeData theme,
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: OwnerDashboardColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your changes save automatically and apply across the app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _statusPill(
          context: context,
          label: settings.isSaving ? 'Saving...' : 'Auto-saved',
          icon: settings.isSaving ? Icons.cloud_upload : Icons.cloud_done,
          color: settings.isSaving
              ? OwnerDashboardColors.brandPrimaryHover(context)
              : OwnerDashboardColors.brandPrimary(context),
        ),
      ],
    );
  }

  Widget _glassSection(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final elevated = OwnerDashboardColors.elevatedBackground(context);
    final card = OwnerDashboardColors.cardBackground(context);
    final border = OwnerDashboardColors.border(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final brandHover = OwnerDashboardColors.brandPrimaryHover(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                elevated.withValues(alpha: isDark ? 0.72 : 0.9),
                card.withValues(alpha: isDark ? 0.66 : 0.86),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: border.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: isDark ? 0.18 : 0.1),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [brand, brandHover],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: OwnerDashboardColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: OwnerDashboardColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(BuildContext context, String message) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withAlpha(20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.errorRed.withAlpha(90)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _securitySection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: OwnerDashboardColors.textPrimary(context),
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: OwnerDashboardColors.textSecondary(context),
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: OwnerDashboardColors.brandPrimaryHover(
                      context,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showChangePasswordDialog(context, ref),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: Text(
                    'Change Password',
                    style: titleStyle?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Security changes sync instantly to your account.',
            style: subtitleStyle?.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _systemSection(
    BuildContext context,
    WidgetRef ref,
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: OwnerDashboardColors.textSecondary(context),
    );
    return Column(
      children: [
        _settingTile(
          context,
          icon: Icons.notifications_active_outlined,
          title: 'Rent Due Reminder',
          subtitle: 'Receive alerts when unpaid rent is due today.',
          child: Switch.adaptive(
            value: settings.rentDueNotificationsEnabled,
            onChanged: (value) async {
              if (value) {
                await ref
                    .read(pushNotificationServiceProvider)
                    .requestPermission();
              }
              notifier.setRentDueNotificationsEnabled(value);
            },
          ),
        ),
        const SizedBox(height: 12),
        _settingTile(
          context,
          icon: Icons.payments_outlined,
          title: 'Payment Received Confirmation',
          subtitle: 'Receive confirmation when rent payment is marked paid.',
          child: Switch.adaptive(
            value: settings.paymentReceivedNotificationsEnabled,
            onChanged: (value) async {
              if (value) {
                await ref
                    .read(pushNotificationServiceProvider)
                    .requestPermission();
              }
              notifier.setPaymentReceivedNotificationsEnabled(value);
            },
          ),
        ),
        const SizedBox(height: 12),
        _settingTile(
          context,
          icon: Icons.dark_mode_outlined,
          title: 'Dark Mode',
          subtitle: 'Use a darker color scheme.',
          child: Switch.adaptive(
            value: settings.darkMode,
            onChanged: notifier.setDarkMode,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Theme and notification preferences are applied immediately.',
            style: subtitleStyle?.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _settingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OwnerDashboardColors.elevatedBackground(
          context,
        ).withValues(alpha: OwnerDashboardColors.isDark(context) ? 0.66 : 0.84),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: OwnerDashboardColors.border(context).withValues(alpha: 0.9),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  OwnerDashboardColors.brandPrimary(context),
                  OwnerDashboardColors.brandPrimaryHover(context),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: OwnerDashboardColors.textPrimary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: OwnerDashboardColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _liquidBlob({
    required BuildContext context,
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required bool isDark,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.14)
              : OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.1),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          bool hideCurrent = true;
          bool hideNew = true;
          bool hideConfirm = true;
          bool isSubmitting = false;
          String? inlineError;

          InputDecoration liquidInput({
            required String label,
            required IconData icon,
            required bool hidden,
            required VoidCallback toggle,
          }) {
            return InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: OwnerDashboardColors.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: Icon(
                icon,
                color: OwnerDashboardColors.brandPrimary(context),
                size: 20,
              ),
              suffixIcon: IconButton(
                onPressed: toggle,
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? OwnerDashboardColors.elevatedBackground(
                      context,
                    ).withValues(alpha: 0.58)
                  : OwnerDashboardColors.cardBackground(
                      context,
                    ).withValues(alpha: 0.95),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: OwnerDashboardColors.border(context),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: OwnerDashboardColors.border(context),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: OwnerDashboardColors.brandPrimary(context),
                  width: 1.2,
                ),
              ),
            );
          }

          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            OwnerDashboardColors.elevatedBackground(
                              context,
                            ).withValues(alpha: isDark ? 0.86 : 0.96),
                            OwnerDashboardColors.cardBackground(
                              context,
                            ).withValues(alpha: isDark ? 0.76 : 0.9),
                          ],
                        ),
                        border: Border.all(
                          color: OwnerDashboardColors.brandPrimary(
                            context,
                          ).withValues(alpha: isDark ? 0.40 : 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(
                              alpha: isDark ? 0.34 : 0.12,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: OwnerDashboardColors.brandPrimary(
                                    context,
                                  ).withValues(alpha: isDark ? 0.28 : 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: OwnerDashboardColors.brandPrimary(
                                      context,
                                    ).withValues(alpha: isDark ? 0.44 : 0.24),
                                  ),
                                ),
                                child: Icon(
                                  Icons.lock_reset_rounded,
                                  size: 18,
                                  color: OwnerDashboardColors.textPrimary(
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Change Password',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: OwnerDashboardColors.textPrimary(
                                          context,
                                        ),
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use a strong new password to keep your account secure.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: OwnerDashboardColors.textSecondary(
                                    context,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: currentController,
                            obscureText: hideCurrent,
                            decoration: liquidInput(
                              label: 'Current password',
                              icon: Icons.lock_outline_rounded,
                              hidden: hideCurrent,
                              toggle: () {
                                setState(() => hideCurrent = !hideCurrent);
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: newController,
                            obscureText: hideNew,
                            decoration: liquidInput(
                              label: 'New password',
                              icon: Icons.enhanced_encryption_rounded,
                              hidden: hideNew,
                              toggle: () {
                                setState(() => hideNew = !hideNew);
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: confirmController,
                            obscureText: hideConfirm,
                            decoration: liquidInput(
                              label: 'Confirm new password',
                              icon: Icons.shield_rounded,
                              hidden: hideConfirm,
                              toggle: () {
                                setState(() => hideConfirm = !hideConfirm);
                              },
                            ),
                          ),
                          if (inlineError != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              inlineError!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.errorRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      OwnerDashboardColors.brandPrimary(
                                        context,
                                      ),
                                  foregroundColor: isDark
                                      ? AppColors.white
                                      : AppColors.cFF0F172A,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final currentPassword =
                                            currentController.text.trim();
                                        final newPassword = newController.text
                                            .trim();
                                        final confirmPassword =
                                            confirmController.text.trim();

                                        if (newPassword != confirmPassword) {
                                          setState(() {
                                            inlineError =
                                                'New password and confirm password must match.';
                                          });
                                          return;
                                        }

                                        setState(() {
                                          isSubmitting = true;
                                          inlineError = null;
                                        });

                                        try {
                                          await ref
                                              .read(authRepositoryProvider)
                                              .changePassword(
                                                currentPassword:
                                                    currentPassword,
                                                newPassword: newPassword,
                                              );

                                          if (!context.mounted) return;
                                          Navigator.of(dialogContext).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Password changed successfully.',
                                              ),
                                            ),
                                          );
                                        } catch (error) {
                                          if (!context.mounted) return;
                                          setState(() {
                                            inlineError = error.toString();
                                          });
                                        } finally {
                                          if (context.mounted) {
                                            setState(() {
                                              isSubmitting = false;
                                            });
                                          }
                                        }
                                      },
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 18,
                                      ),
                                label: const Text('Update'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(signOutUseCaseProvider).call();
      if (!context.mounted) return;
      context.goNamed('roleSelection');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
