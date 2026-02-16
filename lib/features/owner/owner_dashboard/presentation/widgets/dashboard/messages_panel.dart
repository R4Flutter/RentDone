import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/messages_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';

class MessagesPanel extends ConsumerWidget {
  const MessagesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(messagesProvider);

    final allMessages = async.asData?.value ?? const <AppMessage>[];
    final messages =
        allMessages.where(_isPaymentMessage).toList(growable: false);
    final useFallback = messages.isEmpty;
    final items = useFallback ? _fallbackMessages() : messages;

    return DashboardCard(
      useGradient: false,
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
              if (async.hasError)
                _StatusPill(
                  label: 'Offline',
                  color: scheme.error,
                )
              else if (!async.isLoading && useFallback)
                _StatusPill(
                  label: 'Sample',
                  color: scheme.primary,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (async.isLoading)
            const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            Text(
              'No payment updates right now',
              style: theme.textTheme.bodyMedium,
            )
          else
            Column(
              children: items.map((m) {
                return _MessageTile(message: m);
              }).toList(),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.12, end: 0);
  }

  List<AppMessage> _fallbackMessages() {
    final now = DateTime.now();
    final month = _monthShort(now);
    return [
      AppMessage(
        id: 'demo-1',
        type: 'receipt',
        title: 'Rahul Sharma paid rent',
        body: 'UPI payment received for $month rent (\u20B912,000)',
        severity: 'info',
        tenantId: null,
        paymentId: null,
        read: false,
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      AppMessage(
        id: 'demo-2',
        type: 'receipt',
        title: 'Anita Verma paid rent',
        body: 'Cash collected for $month rent (\u20B99,500)',
        severity: 'info',
        tenantId: null,
        paymentId: null,
        read: true,
        createdAt: now.subtract(const Duration(hours: 2)),
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

  bool _isPaymentMessage(AppMessage message) {
    final type = message.type.toLowerCase();
    return type == 'receipt' || type == 'payment';
  }
}

class _MessageTile extends StatelessWidget {
  final AppMessage message;

  const _MessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _severityColor(scheme, message.severity);
    final icon = _typeIcon(message.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(message.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'receipt':
        return Icons.receipt_long_rounded;
      case 'overdue':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _severityColor(ColorScheme scheme, String severity) {
    switch (severity) {
      case 'critical':
        return scheme.error;
      case 'warn':
        return Colors.orange;
      default:
        return scheme.primary;
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}
