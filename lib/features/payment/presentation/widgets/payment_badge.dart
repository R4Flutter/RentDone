import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class PaymentBadge extends StatelessWidget {
  final String label;
  final String status;

  const PaymentBadge({super.key, required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
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
        return AppTheme.nearBlack;
    }
  }
}
