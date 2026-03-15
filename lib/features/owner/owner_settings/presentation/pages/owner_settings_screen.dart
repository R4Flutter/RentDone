import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
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
                gradient:
                    OwnerDashboardColors.managePropertiesBackgroundGradient(
                      context,
                    ),
              ),
            ),
          ),
          _liquidBlob(top: -80, left: -58, size: 300, isDark: isDark),
          _liquidBlob(bottom: -92, right: -60, size: 260, isDark: isDark),
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
                                          settings,
                                          notifier,
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
                                  child: _securitySection(
                                    context,
                                    ref,
                                    settings,
                                    notifier,
                                    theme,
                                  ),
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
                  color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                    context,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your changes save automatically and apply across the app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                    context,
                  ),
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
              ? AppTheme.warningAmber
              : AppTheme.successGreen,
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
              colors: isDark
                  ? [Colors.white.withAlpha(20), Colors.white.withAlpha(10)]
                  : [Colors.white.withAlpha(188), Colors.white.withAlpha(140)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withAlpha(48),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: OwnerDashboardColors.managePropertiesShadowColor(
                  context,
                ),
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
                      gradient:
                          OwnerDashboardColors.managePropertiesAccentGradient(
                            context,
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
                            color:
                                OwnerDashboardColors.managePropertiesHeaderPrimary(
                                  context,
                                ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color:
                                OwnerDashboardColors.managePropertiesHeaderSecondary(
                                  context,
                                ),
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
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: OwnerDashboardColors.managePropertiesHeaderPrimary(context),
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: OwnerDashboardColors.managePropertiesHeaderSecondary(context),
    );
    return Column(
      children: [
        _settingTile(
          context,
          icon: Icons.phonelink_lock,
          title: 'Enable Two-Factor Authentication',
          subtitle: 'Adds an extra verification step on login.',
          child: Switch.adaptive(
            value: settings.enable2FA,
            onChanged: notifier.setEnable2FA,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        OwnerDashboardColors.managePropertiesActionColor(
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
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: OwnerDashboardColors.managePropertiesHeaderSecondary(context),
    );
    return Column(
      children: [
        _settingTile(
          context,
          icon: Icons.notifications_active_outlined,
          title: 'Enable Notifications',
          subtitle: 'Receive rent alerts and reminders.',
          child: Switch.adaptive(
            value: settings.notificationsEnabled,
            onChanged: notifier.setNotificationsEnabled,
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
        color: AppTheme.pureWhite.withAlpha(90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: OwnerDashboardColors.managePropertiesPillBorder(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: OwnerDashboardColors.managePropertiesAccentGradient(
                context,
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
                    color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                      context,
                    ),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                      context,
                    ),
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
              ? AppTheme.liquidPrimaryStart.withAlpha(20)
              : AppTheme.liquidPrimaryStart.withAlpha(30),
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

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final currentPassword = currentController.text.trim();
                  final newPassword = newController.text.trim();
                  final confirmPassword = confirmController.text.trim();

                  if (newPassword != confirmPassword) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'New password and confirm password must match.',
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .changePassword(
                          currentPassword: currentPassword,
                          newPassword: newPassword,
                        );

                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully.'),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                child: const Text('Update'),
              ),
            ],
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
