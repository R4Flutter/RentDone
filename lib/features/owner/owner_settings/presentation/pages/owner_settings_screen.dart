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
    final settings = ref.watch(ownerSettingsProvider);
    final notifier = ref.read(ownerSettingsProvider.notifier);
    final isDesktop = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1200 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeader(theme, settings),
                if (settings.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    settings.errorMessage!,
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                ],
                const SizedBox(height: 24),
                if (settings.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _sectionCard(
                              theme,
                              icon: Icons.shield_outlined,
                              title: 'Security',
                              subtitle: 'Protect your account access.',
                              child: _securitySection(
                                context,
                                ref,
                                settings,
                                notifier,
                                theme,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sectionCard(
                              theme,
                              icon: Icons.tune,
                              title: 'Preferences',
                              subtitle: 'Notifications and display.',
                              child: _systemSection(settings, notifier, theme),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _sectionCard(
                    theme,
                    icon: Icons.shield_outlined,
                    title: 'Security',
                    subtitle: 'Protect your account access.',
                    child: _securitySection(
                      context,
                      ref,
                      settings,
                      notifier,
                      theme,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionCard(
                    theme,
                    icon: Icons.tune,
                    title: 'Preferences',
                    subtitle: 'Notifications and display.',
                    child: _systemSection(settings, notifier, theme),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(ThemeData theme, OwnerSettingsState settings) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: theme.textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Your changes save automatically and apply across the app.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        _statusPill(
          label: settings.isSaving ? 'Saving...' : 'Auto-saved',
          icon: settings.isSaving ? Icons.cloud_upload : Icons.cloud_done,
          color: settings.isSaving
              ? AppTheme.warningAmber
              : AppTheme.successGreen,
        ),
      ],
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _statusPill({
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
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
      color: theme.colorScheme.onPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
    );
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: settings.enable2FA,
          onChanged: notifier.setEnable2FA,
          title: Text('Enable Two-Factor Authentication', style: titleStyle),
          subtitle: Text(
            'Adds an extra verification step on login.',
            style: subtitleStyle,
          ),
          secondary: Icon(
            Icons.phonelink_lock,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _showChangePasswordDialog(context, ref),
          icon: const Icon(Icons.lock_reset),
          label: const Text('Change Password'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _logout(context, ref),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }

  Widget _systemSection(
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
    );
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: settings.notificationsEnabled,
          onChanged: notifier.setNotificationsEnabled,
          title: Text('Enable Notifications', style: titleStyle),
          subtitle: Text(
            'Receive rent alerts and reminders.',
            style: subtitleStyle,
          ),
          secondary: Icon(
            Icons.notifications_active_outlined,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        SwitchListTile.adaptive(
          value: settings.darkMode,
          onChanged: notifier.setDarkMode,
          title: Text('Dark Mode', style: titleStyle),
          subtitle: Text('Use a darker color scheme.', style: subtitleStyle),
          secondary: Icon(
            Icons.dark_mode_outlined,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ],
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
