import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:go_router/go_router.dart';

class TenantProfileScreen extends ConsumerWidget {
  const TenantProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final dashboardAsync = ref.watch(tenantDashboardProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading profile: $e')),
        data: (summary) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(context, user?.email, theme, scheme),
              const SizedBox(height: 24),
              _buildInfoSection(context, 'Personal Information', [
                _buildInfoRow(
                  context,
                  Icons.email_outlined,
                  'Email',
                  user?.email ?? 'Not available',
                ),
                if (summary.propertyName != null)
                  _buildInfoRow(
                    context,
                    Icons.home_outlined,
                    'Property',
                    summary.propertyName!,
                  ),
                if (summary.roomNumber != null)
                  _buildInfoRow(
                    context,
                    Icons.door_front_door_outlined,
                    'Room',
                    summary.roomNumber!,
                  ),
              ]),
              const SizedBox(height: 16),
              _buildInfoSection(context, 'Lease Information', [
                _buildInfoRow(
                  context,
                  Icons.calendar_today_outlined,
                  'Move-in Date',
                  summary.leaseStartDate != null
                      ? _formatDate(summary.leaseStartDate!)
                      : 'Not available',
                ),
                if (summary.leaseEndDate != null)
                  _buildInfoRow(
                    context,
                    Icons.event_outlined,
                    'Lease End Date',
                    _formatDate(summary.leaseEndDate!),
                  ),
                _buildInfoRow(
                  context,
                  Icons.payments_outlined,
                  'Monthly Rent',
                  '\u20B9${_formatInr(summary.rentAmount)}',
                ),
              ]),
              const SizedBox(height: 16),
              if (summary.ownerName != null || summary.ownerPhone != null)
                _buildInfoSection(context, 'Owner Contact', [
                  if (summary.ownerName != null)
                    _buildInfoRow(
                      context,
                      Icons.person_outline,
                      'Owner Name',
                      summary.ownerName!,
                    ),
                  if (summary.ownerPhone != null)
                    _buildInfoRow(
                      context,
                      Icons.phone_outlined,
                      'Phone',
                      summary.ownerPhone!,
                    ),
                ]),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FilledButton.icon(
                  onPressed: () => _handleLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String? email,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      decoration: const BoxDecoration(gradient: AppTheme.blueSurfaceGradient),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.pureWhite.withValues(alpha: 0.2),
            child: const Icon(
              Icons.person,
              size: 50,
              color: AppTheme.pureWhite,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            email ?? 'Tenant',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.pureWhite,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Tenant Account',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.pureWhite.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(signOutUseCaseProvider).call();
        if (context.mounted) {
          context.go('/roleSelection');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatInr(int value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    if (digits.length <= 3) return '$sign$digits';

    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) {
      parts.insert(0, rest);
    }
    return '$sign${parts.join(',')},$last3';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
