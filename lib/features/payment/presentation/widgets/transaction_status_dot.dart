import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class TransactionStatusDot extends StatelessWidget {
  final String status;

  const TransactionStatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _statusColor(status),
      ),
    );
  }

  Color _statusColor(String status) {
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
