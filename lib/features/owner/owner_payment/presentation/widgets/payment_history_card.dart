import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/payment_status_badge.dart';

class PaymentHistoryCard extends StatefulWidget {
  const PaymentHistoryCard({super.key, required this.payment});

  final TenantPaymentRecord payment;

  @override
  State<PaymentHistoryCard> createState() => _PaymentHistoryCardState();
}

class _PaymentHistoryCardState extends State<PaymentHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _expanded = !_expanded),
      child: DashboardCard(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _monthLabel(payment.date),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: OwnerDashboardColors.textPrimary(context),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Paid Rs ${payment.amount} on ${_readableDate(payment.date)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OwnerDashboardColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PaymentStatusBadge(status: payment.status),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'Method: ${payment.method}'),
                _chip(context, 'Date: ${_readableDate(payment.date)}'),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((payment.transactionId ?? '').isNotEmpty)
                      _detailRow(
                        context,
                        label: 'Transaction ID',
                        value: payment.transactionId!,
                      ),
                    if ((payment.notes ?? '').isNotEmpty)
                      _detailRow(
                        context,
                        label: 'Notes',
                        value: payment.notes!,
                      ),
                    _detailRow(
                      context,
                      label: 'Created',
                      value: _readableDateTime(payment.createdAt),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: OwnerDashboardColors.brandPrimary(
          context,
        ).withValues(alpha: OwnerDashboardColors.isDark(context) ? 0.10 : 0.06),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: OwnerDashboardColors.textPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OwnerDashboardColors.textSecondary(context),
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: OwnerDashboardColors.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _monthLabel(DateTime date) {
    const months = <String>[
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
    return '${months[date.month - 1]} ${date.year}';
  }

  String _readableDate(DateTime date) {
    const months = <String>[
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _readableDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_readableDate(date)} $hour:$minute';
  }
}
