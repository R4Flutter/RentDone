import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_stat_card.dart';

class TenantDashboardScreen extends ConsumerWidget {
  const TenantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(tenantDashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(
                context,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.12, end: 0),
              const SizedBox(height: 24),
              _buildStatsGrid(context, summary),
              const SizedBox(height: 24),
              _buildPropertyCard(context, summary),
              const SizedBox(height: 16),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildRecentActivity(context, summary),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage your rent and stay organized',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppTheme.blueSurfaceGradient,
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.pureWhite,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your rent summary this month',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.pureWhite.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Image.asset(
                  'assets/images/tenant_final.png',
                  height: 54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context, dynamic summary) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 3 : 2;
    final aspect = width >= 900 ? 1.2 : 0.9;

    final cards = [
      TenantStatCard(
        title: 'Due Rent',
        value: '\u20B9${_formatInr(summary.pendingAmount)}',
        subtitle: summary.nextDueDate != null
            ? 'Due ${_formatDate(summary.nextDueDate!)}'
            : 'No dues',
        icon: Icons.calendar_today_rounded,
        color: summary.pendingAmount > 0 ? Colors.red : Colors.green,
      ),
      TenantStatCard(
        title: 'Paid This Month',
        value: '\u20B9${_formatInr(summary.rentAmount)}',
        subtitle: '${summary.successfulPayments} payments',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      ),
      TenantStatCard(
        title: 'Total Paid',
        value: '\u20B9${_formatInr(summary.paidAmount)}',
        subtitle: '${summary.totalTransactions} transactions',
        icon: Icons.account_balance_wallet_rounded,
        color: Colors.blue,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: aspect,
      children: List.generate(cards.length, (index) {
        return cards[index]
            .animate()
            .fadeIn(duration: 400.ms, delay: (90 * index).ms)
            .slideY(begin: 0.15, end: 0);
      }),
    );
  }

  Widget _buildPropertyCard(BuildContext context, dynamic summary) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
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
            Row(
              children: [
                Icon(Icons.home_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Your Property',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _propertyRow(
              Icons.apartment_rounded,
              'Property',
              summary.propertyName ?? 'Not assigned',
            ),
            const SizedBox(height: 12),
            _propertyRow(
              Icons.door_front_door_rounded,
              'Room',
              summary.roomNumber ?? '-',
            ),
            const SizedBox(height: 12),
            _propertyRow(
              Icons.person_outline_rounded,
              'Owner',
              summary.ownerName ?? '-',
            ),
            if (summary.ownerPhone != null) ...[
              const SizedBox(height: 12),
              _propertyRow(Icons.phone_rounded, 'Contact', summary.ownerPhone!),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 270.ms);
  }

  Widget _propertyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.go('/tenant/transactions'),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('View Payments'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Contact Owner'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 360.ms);
  }

  Widget _buildRecentActivity(BuildContext context, dynamic summary) {
    final theme = Theme.of(context);

    final scheme = theme.colorScheme;

    return Card(
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
              'Recent Activity',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _activityItem(
              Icons.check_circle_rounded,
              'Payment Successful',
              '\u20B9${_formatInr(summary.rentAmount)}',
              'Feb 1, 2026',
              Colors.green,
            ),
            const Divider(height: 24),
            _activityItem(
              Icons.info_outline_rounded,
              'Lease Reminder',
              'Renewal due in 30 days',
              'Jan 15, 2026',
              Colors.orange,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 450.ms);
  }

  Widget _activityItem(
    IconData icon,
    String title,
    String subtitle,
    String date,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
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
