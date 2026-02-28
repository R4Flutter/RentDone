import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_glass.dart';

class TenantDashboardScreen extends ConsumerWidget {
  const TenantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(tenantDashboardProvider);

    return summaryAsync.when(
      loading: () => const _DarkScaffoldBody(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _DarkScaffoldBody(
        child: Center(
          child: Text(
            'Failed to load dashboard',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
      ),
      data: (summary) {
        if (summary.tenantId.isEmpty) {
          return const _DarkScaffoldBody(
            child: Center(
              child: Text(
                'Setting up your account...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final monthPaymentAsync = ref.watch(
          currentMonthPaymentProvider(summary.tenantId),
        );
        final remindersAsync = ref.watch(
          recentTenantRemindersProvider(summary.tenantId),
        );

        return _DarkScaffoldBody(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tenantDashboardProvider);
              ref.invalidate(currentMonthPaymentProvider(summary.tenantId));
              ref.invalidate(recentTenantRemindersProvider(summary.tenantId));
              await ref.read(tenantDashboardProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _TopBar(summary: summary),
                const SizedBox(height: 16),
                _FinancialHubCard(summary: summary),
                const SizedBox(height: 14),
                monthPaymentAsync.when(
                  data: (payment) => _DueCard(
                    summary: summary,
                    amount: payment?.amount,
                    isAmountRefreshing: false,
                    onPayNow: () {
                      unawaited(
                        ref
                            .read(transactionHistoryProvider.notifier)
                            .loadInitial(actor: TransactionActor.tenant),
                      );
                      context.go('/tenant/transactions');
                    },
                  ),
                  loading: () => _DueCard(
                    summary: summary,
                    amount: summary.dueAmount,
                    isAmountRefreshing: true,
                    onPayNow: () {
                      context.go('/tenant/transactions');
                    },
                  ),
                  error: (_, _) => _DueCard(
                    summary: summary,
                    amount: null,
                    isAmountRefreshing: false,
                    onPayNow: () {
                      unawaited(
                        ref
                            .read(transactionHistoryProvider.notifier)
                            .loadInitial(actor: TransactionActor.tenant),
                      );
                      context.go('/tenant/transactions');
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _StatsRow(summary: summary),
                const SizedBox(height: 18),
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    _ActionTile(
                      icon: Icons.payments_rounded,
                      title: 'Payments',
                      subtitle: 'Due & History',
                      onTap: () => context.go('/tenant/transactions'),
                    ),
                    _ActionTile(
                      icon: Icons.wallet_outlined,
                      title: 'Vault',
                      subtitle: 'Documents',
                      onTap: () => context.go('/tenant/documents'),
                    ),
                    _ActionTile(
                      icon: Icons.description_outlined,
                      title: 'Complaints',
                      subtitle: 'Submit / Track',
                      onTap: () => context.go('/tenant/complaints'),
                    ),
                    _ActionTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      subtitle: 'Account',
                      onTap: () => context.go('/tenant/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                remindersAsync.when(
                  data: (items) => _VaultUpdates(
                    reminders: items,
                    onTap: () => context.go('/tenant/documents'),
                  ),
                  loading: () => const _SkeletonCard(height: 90),
                  error: (_, _) => const _SkeletonCard(height: 90),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DarkScaffoldBody extends StatelessWidget {
  final Widget child;

  const _DarkScaffoldBody({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.nearBlack,
      child: SafeArea(child: child),
    );
  }
}

class _TopBar extends StatelessWidget {
  final dynamic summary;

  const _TopBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/rentdone_logo.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RentDone',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                summary.propertyName.isEmpty
                    ? 'Your Home Dashboard'
                    : summary.propertyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.25),
          child: Icon(
            Icons.notifications_none_rounded,
            color: scheme.onPrimary,
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _FinancialHubCard extends StatelessWidget {
  final dynamic summary;

  const _FinancialHubCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = NumberFormat('#,##,##0', 'en_IN');

    return TenantGlassCard(
      accent: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Hub',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${formatter.format(summary.monthlyRent)}',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Pill(text: 'Room ${summary.roomNumber}'),
              const SizedBox(width: 8),
              _Pill(text: 'Due Day ${summary.rentDueDay}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  final dynamic summary;
  final int? amount;
  final bool isAmountRefreshing;
  final VoidCallback onPayNow;

  const _DueCard({
    required this.summary,
    this.amount,
    required this.onPayNow,
    this.isAmountRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    final due = amount ?? summary.dueAmount;

    return TenantGlassCard(
      accent: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Dues',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${formatter.format(due)}',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            due > 0 ? 'Payment pending this month' : 'No pending dues',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          if (isAmountRefreshing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Updating latest due amount...',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPayNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.65),
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pay Now'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final dynamic summary;

  const _StatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Lifetime Paid',
            value: '₹${formatter.format(summary.lifetimePaid)}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(title: 'Growing', value: '+12.4%'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TenantGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TenantGlassCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(12),
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: scheme.onPrimary.withValues(alpha: 0.95),
                size: 20,
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onPrimary.withValues(alpha: 0.78),
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.66),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap to open',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultUpdates extends StatelessWidget {
  final List<dynamic> reminders;
  final VoidCallback onTap;

  const _VaultUpdates({required this.reminders, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = reminders.isEmpty
        ? 'All updates are synced'
        : (reminders.first.title.isNotEmpty
              ? reminders.first.title
              : reminders.first.body);

    return TenantGlassCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      accent: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: scheme.onPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vault Updates',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onPrimary.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onPrimary.withValues(alpha: 0.85),
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;

  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
