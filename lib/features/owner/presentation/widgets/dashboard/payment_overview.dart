import 'package:flutter/material.dart';
import 'package:rentdone/features/owner/domain/entities/dashboard_summary.dart';



class PaymentsOverview extends StatelessWidget {
  final DashboardSummary summary;
  const PaymentsOverview({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
    
      child: Column(
        children: [
          _PaymentRow(
            label: 'Cash Payments',
            value: '₹${summary.cashAmount}',
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 12),
          _PaymentRow(
            label: 'Online Payments',
            value: '₹${summary.onlineAmount}',
            color: Colors.indigo,
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
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.account_balance_wallet, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}