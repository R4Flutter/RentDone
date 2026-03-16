import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();

    final Color color;
    final String label;

    if (normalized == 'paid') {
      color = AppTheme.successGreen;
      label = 'Paid';
    } else if (normalized == 'partial') {
      color = AppTheme.warningAmber;
      label = 'Partial';
    } else {
      color = AppTheme.errorRed;
      label = 'Unpaid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
