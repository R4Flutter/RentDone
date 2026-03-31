import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class PaymentBadge extends StatelessWidget {
  final String label;
  final String status;

  const PaymentBadge({super.key, required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    final background =
        Color.lerp(AppColors.white, color, 0.08) ?? AppColors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.8,
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
        return AppTheme.nearBlack;
    }
  }
}
