import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_data_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/messages_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';

class MessagesPanel extends ConsumerWidget {
  const MessagesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(messagesProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final summary = summaryAsync.asData?.value ?? DashboardSummary.empty;

    final allMessages = messagesAsync.asData?.value ?? const <AppMessage>[];
    final livePaymentMessages = allMessages
        .where(_isTimelineMessage)
        .toList(growable: false);
    final items = livePaymentMessages.isEmpty
        ? _fallbackMessages(summary)
        : livePaymentMessages;

    return DashboardCard(
      useGradient: false,
      backgroundColor: OwnerDashboardColors.activityCardBackground(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment Updates',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Updates from the last 7 days. Older messages are removed automatically.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: OwnerDashboardColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          if (messagesAsync.isLoading)
            const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            Text(
              'No payment updates in the last 7 days',
              style: theme.textTheme.bodyMedium,
            )
          else
            Column(
              children: items.map((message) {
                return _MessageTile(message: message);
              }).toList(),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.12, end: 0);
  }

  bool _isTimelineMessage(AppMessage message) {
    final type = message.type.toLowerCase();
    return type == 'receipt' ||
        type == 'payment' ||
        type == 'overdue' ||
        type == 'tenant';
  }

  List<AppMessage> _fallbackMessages(DashboardSummary summary) {
    final now = DateTime.now();
    final month = _monthShort(now);

    final collectionLine =
        'Collected Rs ${_formatInr(summary.collectedAmount)} in $month';
    final pendingLine = summary.pendingPayments > 0
        ? '${summary.pendingPayments} pending payments (Rs ${_formatInr(summary.pendingAmount)})'
        : 'No pending rent for $month';

    return [
      AppMessage(
        id: 'dynamic-fallback-1',
        type: 'receipt',
        title: 'Monthly collection updated',
        body: collectionLine,
        severity: 'info',
        tenantId: null,
        paymentId: null,
        read: false,
        createdAt: now.subtract(const Duration(minutes: 3)),
      ),
      AppMessage(
        id: 'dynamic-fallback-2',
        type: summary.pendingPayments > 0 ? 'overdue' : 'receipt',
        title: 'Current payment snapshot',
        body: pendingLine,
        severity: summary.pendingPayments > 0 ? 'warn' : 'info',
        tenantId: null,
        paymentId: null,
        read: true,
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
    ];
  }

  String _monthShort(DateTime now) {
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
    return months[now.month - 1];
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
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor(context, message.severity);
    final icon = _typeIcon(message.type);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: OwnerDashboardColors.activityCardBackground(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: OwnerDashboardColors.activityCardBorder(context),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (compact) ...[
                      Text(
                        message.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatUpdateTime(message.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: OwnerDashboardColors.textSecondary(context),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatUpdateTime(message.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: OwnerDashboardColors.textSecondary(
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(
                      message.body,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: OwnerDashboardColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'receipt':
        return Icons.receipt_long_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'tenant':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _severityColor(BuildContext context, String severity) {
    switch (severity) {
      case 'critical':
        return Theme.of(context).colorScheme.error;
      case 'warn':
        return OwnerDashboardColors.pendingTone(context).iconColor;
      default:
        return OwnerDashboardColors.brandPrimary(context);
    }
  }

  String _formatUpdateTime(DateTime time) {
    return DateFormat('dd MMM, hh:mm a').format(time);
  }
}
