import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_data_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/messages_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

class RecentActivity extends ConsumerWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final messagesAsync = ref.watch(messagesProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    final summary = summaryAsync.asData?.value ?? DashboardSummary.empty;
    final messages = messagesAsync.asData?.value ?? const <AppMessage>[];
    final items = _buildActivityItems(messages, summary);

    return DashboardCard(
      useGradient: false,
      backgroundColor: OwnerDashboardColors.activityCardBackground(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: OwnerDashboardColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          if (messagesAsync.isLoading && items.isEmpty)
            const SizedBox(
              height: 84,
              child: Center(child: AppLoadingIndicator()),
            )
          else
            ...items
                .take(4)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActivityRow(
                      icon: item.icon,
                      text: item.text,
                      time: item.time,
                      color: item.color,
                    ),
                  ),
                ),
        ],
      ),
    ).animate().fadeIn(duration: 540.ms).slideY(begin: 0.12, end: 0);
  }

  List<_ActivityItem> _buildActivityItems(
    List<AppMessage> messages,
    DashboardSummary summary,
  ) {
    final items = <_ActivityItem>[];

    for (final message in messages.take(3)) {
      items.add(
        _ActivityItem(
          icon: _iconForType(message.type),
          text: message.title,
          time: _timeAgo(message.createdAt),
          color: _colorForSeverity(message.severity),
        ),
      );
    }

    if (summary.collectedPayments > 0 || summary.pendingPayments > 0) {
      items.add(
        _ActivityItem(
          icon: Icons.analytics_rounded,
          text:
              'Collected ${summary.collectedPayments} payments, pending ${summary.pendingPayments}',
          time: 'Live',
          color: AppTheme.infoBlue,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _ActivityItem(
          icon: Icons.insights_rounded,
          text: 'Dashboard is live. New activity will appear here.',
          time: 'now',
          color: AppTheme.infoBlue,
        ),
      );
    }

    return items;
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'receipt':
      case 'payment':
        return Icons.payments_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'tenant':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppTheme.errorRed;
      case 'warn':
        return AppTheme.warningAmber;
      default:
        return AppTheme.infoBlue;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.text,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String text;
  final String time;
  final Color color;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.text,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String text;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: OwnerDashboardColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: textTheme.bodySmall?.copyWith(
                      color: OwnerDashboardColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
