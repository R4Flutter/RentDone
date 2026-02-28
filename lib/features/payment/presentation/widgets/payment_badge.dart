import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class PaymentBadge extends StatelessWidget {
  final String label;
  final String status;

  const PaymentBadge({super.key, required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    final icon = _iconFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
        return AppTheme.successGreen;
      case 'failed':
        return AppTheme.errorRed;
      case 'pending':
        return AppTheme.warningAmber;
      default:
        return Colors.white70;
    }
  }

  IconData _iconFor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
        return Icons.check_circle_outline_rounded;
      case 'failed':
        return Icons.error_outline_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'refunded':
        return Icons.replay_rounded;
      default:
        return Icons.circle_outlined;
    }
  }
}
