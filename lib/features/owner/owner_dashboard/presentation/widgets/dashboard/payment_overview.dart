import 'package:flutter/material.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';

class PaymentsOverview extends StatelessWidget {
  final DashboardSummary summary;
  const PaymentsOverview({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        children: [
          _PaymentRow(
            label: 'Cash Payments',
            value: '₹${summary.cashAmount}',
            color: scheme.onSurface, // neutral
          ),
          const SizedBox(height: 12),
          _PaymentRow(
            label: 'Online Payments',
            value: '₹${summary.onlineAmount}',
            color: scheme.primary, // brand
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PaymentRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.12), // M3-safe
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}