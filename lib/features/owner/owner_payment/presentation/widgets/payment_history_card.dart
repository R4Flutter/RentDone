import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/payment_status_badge.dart';
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

typedef PaymentStatusCallback =
    Future<void> Function(
      String paymentId,
      String newStatus, {
      int? installmentAmount,
      String? installmentMethod,
      String? installmentNotes,
    });

class PaymentHistoryCard extends StatefulWidget {
  const PaymentHistoryCard({
    super.key,
    required this.payment,
    this.onStatusChanged,
    this.readOnly = false,
  });

  final TenantPaymentRecord payment;
  final PaymentStatusCallback? onStatusChanged;
  final bool readOnly;

  @override
  State<PaymentHistoryCard> createState() => _PaymentHistoryCardState();
}

class _PaymentHistoryCardState extends State<PaymentHistoryCard> {
  bool _expanded = false;
  bool _isUpdating = false;
  String? _updateError;

  Future<void> _updateStatus(
    String newStatus, {
    int? installmentAmount,
    String? installmentMethod,
    String? installmentNotes,
  }) async {
    if (_isUpdating) return;

    final confirmed = await _showConfirmDialog(
      newStatus,
      installmentAmount: installmentAmount,
    );
    if (!confirmed) return;

    setState(() {
      _isUpdating = true;
      _updateError = null;
    });

    try {
      await widget.onStatusChanged?.call(
        widget.payment.id,
        newStatus,
        installmentAmount: installmentAmount,
        installmentMethod: installmentMethod,
        installmentNotes: installmentNotes,
      );
      if (mounted) {
        final extra = installmentAmount != null
            ? ' (Rs $installmentAmount installment added)'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment status updated to ${newStatus.toUpperCase()}$extra',
            ),
            backgroundColor: _statusColor(newStatus),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<bool> _showConfirmDialog(
    String newStatus, {
    int? installmentAmount,
  }) async {
    final payment = widget.payment;
    final message = installmentAmount != null
        ? 'Add installment of Rs $installmentAmount?\n\nRemaining before: Rs ${payment.remainingAmount}'
        : 'Mark this payment as ${newStatus.toUpperCase()}?\n\nBase rent: Rs ${payment.baseAmount}';

    return await GlassDialogHelper.showConfirmDialog(
          context,
          title: 'Update Payment Status',
          message: message,
          confirmText: 'Confirm',
          cancelText: 'Cancel',
          confirmColor: _statusColor(newStatus),
        ) ??
        false;
  }

  Color _statusColor(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'paid') return AppTheme.successGreen;
    if (normalized == 'partial') return AppTheme.warningAmber;
    return AppTheme.errorRed;
  }

  bool _isDigitalMethod(String method) {
    final normalized = method.trim().toLowerCase();
    return normalized.contains('razorpay') ||
        normalized.contains('upi') ||
        normalized.contains('online') ||
        normalized.contains('card') ||
        normalized.contains('netbanking');
  }

  bool _isPaidReceipt(TenantPaymentRecord payment) {
    return payment.status == 'paid' && _isDigitalMethod(payment.method);
  }

  String _receiptId(TenantPaymentRecord payment) {
    final transaction = (payment.transactionId ?? '').trim();
    if (transaction.isNotEmpty) {
      return transaction;
    }
    return payment.id;
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final canUpdate =
        !widget.readOnly &&
        (payment.status == 'unpaid' || payment.status == 'partial');
    final isPartialOutstanding =
        !widget.readOnly &&
        payment.status == 'partial' &&
        payment.remainingAmount > 0;
    final showPaidReceipt = _isPaidReceipt(payment);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _isUpdating ? null : () => setState(() => _expanded = !_expanded),
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
                        'Base: Rs ${payment.baseAmount} | Paid: Rs ${payment.paidAmount}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OwnerDashboardColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                PaymentStatusBadge(status: payment.status),
                if (showPaidReceipt) ...[
                  const SizedBox(width: 8),
                  _receiptBadge(context),
                ],
                const SizedBox(width: 8),
                if (_isUpdating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppLoadingIndicator(strokeWidth: 2),
                  )
                else
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
                _chip(context, 'Remaining: Rs ${payment.remainingAmount}'),
                _chip(context, 'Installments: ${payment.installments.length}'),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
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
                      label: 'Base Rent',
                      value: 'Rs ${payment.baseAmount}',
                    ),
                    _detailRow(
                      context,
                      label: 'Total Paid',
                      value: 'Rs ${payment.paidAmount}',
                    ),
                    _detailRow(
                      context,
                      label: 'Remaining',
                      value: 'Rs ${payment.remainingAmount}',
                    ),
                    _detailRow(
                      context,
                      label: 'Created',
                      value: _readableDateTime(payment.createdAt),
                    ),
                    if (showPaidReceipt) ...[
                      const SizedBox(height: 8),
                      _receiptPanel(context, payment),
                    ],
                    if (payment.installments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Installment Timeline',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: OwnerDashboardColors.textPrimary(context),
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...payment.installments.map(
                        (installment) => _detailRow(
                          context,
                          label:
                              '${_readableDate(installment.date)} (${installment.method})',
                          value: 'Rs ${installment.amount}',
                        ),
                      ),
                    ],
                    if (isPartialOutstanding) ...[
                      const SizedBox(height: 10),
                      _buildInstallmentAction(context),
                    ],
                    if (canUpdate) ...[
                      const SizedBox(height: 14),
                      _buildStatusUpdateSection(context),
                    ],
                    if (_updateError != null) ...[
                      const SizedBox(height: 10),
                      _buildErrorMessage(context),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusUpdateSection(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final currentStatus = widget.payment.status;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: OwnerDashboardColors.brandPrimary(
          context,
        ).withValues(alpha: isDark ? 0.08 : 0.04),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Status',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: OwnerDashboardColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusButton(
                  context,
                  label: 'Paid',
                  status: 'paid',
                  isActive: currentStatus == 'paid',
                  onTap: _isUpdating ? null : () => _updateStatus('paid'),
                ),
                const SizedBox(width: 8),
                _statusButton(
                  context,
                  label: 'Partial',
                  status: 'partial',
                  isActive: currentStatus == 'partial',
                  onTap: _isUpdating
                      ? null
                      : () async {
                          final amount = await _showInstallmentDialog(
                            context,
                            widget.payment.remainingAmount,
                          );
                          if (amount == null) return;
                          await _updateStatus(
                            'partial',
                            installmentAmount: amount,
                            installmentMethod: widget.payment.method,
                          );
                        },
                ),
                const SizedBox(width: 8),
                _statusButton(
                  context,
                  label: 'Unpaid',
                  status: 'unpaid',
                  isActive: currentStatus == 'unpaid',
                  onTap: _isUpdating ? null : () => _updateStatus('unpaid'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentAction(BuildContext context) {
    final remaining = widget.payment.remainingAmount;
    return DashboardCard(
      radius: 14,
      inset: true,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pending Rs $remaining. Add next installment on this same payment card.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: OwnerDashboardColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(
            onPressed: _isUpdating
                ? null
                : () async {
                    final amount = await _showInstallmentDialog(
                      context,
                      remaining,
                    );
                    if (amount == null) return;
                    await _updateStatus(
                      'partial',
                      installmentAmount: amount,
                      installmentMethod: widget.payment.method,
                    );
                  },
            child: const Text('Add Installment'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showInstallmentDialog(
    BuildContext context,
    int remainingAmount,
  ) async {
    if (remainingAmount <= 0) return null;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'installment',
      pageBuilder: (ctx, _, _) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: DashboardCard(
                  radius: 24,
                  useGradient: true,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Installment',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: OwnerDashboardColors.textPrimary(ctx),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Remaining balance: Rs $remainingAmount',
                          style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                            color: OwnerDashboardColors.textSecondary(ctx),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount paid now',
                            prefixText: 'Rs ',
                          ),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid amount';
                            }
                            if (parsed > remainingAmount) {
                              return 'Amount cannot exceed Rs $remainingAmount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                final parsed = int.parse(
                                  controller.text.trim(),
                                );
                                Navigator.of(ctx).pop(parsed);
                              },
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );

    // Dispose after the dialog route reverse animation fully settles.
    // Immediate dispose can race with TextField listeners during pop.
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      controller.dispose();
    });
    return result;
  }

  Widget _statusButton(
    BuildContext context, {
    required String label,
    required String status,
    required bool isActive,
    required VoidCallback? onTap,
  }) {
    final isDark = OwnerDashboardColors.isDark(context);
    final buttonColor = _statusColor(status);

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _isUpdating ? 0.98 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isUpdating ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isActive
                  ? buttonColor.withValues(alpha: isDark ? 0.22 : 0.14)
                  : OwnerDashboardColors.brandPrimary(
                      context,
                    ).withValues(alpha: isDark ? 0.06 : 0.03),
              border: Border.all(
                color: isActive
                    ? buttonColor.withValues(alpha: 0.50)
                    : OwnerDashboardColors.border(context),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: buttonColor,
                    ),
                  ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isActive ? buttonColor : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.errorRed.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _updateError!,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppTheme.errorRed),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _updateError = null),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.successGreen.withValues(alpha: 0.13),
        border: Border.all(
          color: AppTheme.successGreen.withValues(alpha: 0.40),
        ),
      ),
      child: Text(
        'Paid Receipt',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.successGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _receiptPanel(BuildContext context, TenantPaymentRecord payment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.successGreen.withValues(alpha: 0.08),
        border: Border.all(
          color: AppTheme.successGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'Receipt Confirmed',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow(
            context,
            label: 'Paid For Month',
            value: _monthLabel(payment.date),
          ),
          _detailRow(context, label: 'Receipt ID', value: _receiptId(payment)),
          _detailRow(
            context,
            label: 'Paid On',
            value: _readableDateTime(payment.date),
          ),
        ],
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
