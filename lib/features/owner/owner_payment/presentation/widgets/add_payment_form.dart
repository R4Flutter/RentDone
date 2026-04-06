import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

class AddPaymentPayload {
  const AddPaymentPayload({
    required this.baseAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.date,
    required this.method,
    required this.status,
    this.notes,
  });

  final int baseAmount;
  final int paidAmount;
  final int remainingAmount;
  final DateTime date;
  final String method;
  final String status;
  final String? notes;
}

class AddPaymentForm extends StatefulWidget {
  const AddPaymentForm({
    super.key,
    required this.onSubmit,
    this.rentAmount = 0,
    this.existingPayments = const [],
  });

  final Future<void> Function(AddPaymentPayload payload) onSubmit;
  final int rentAmount;
  final List<TenantPaymentRecord> existingPayments;

  @override
  State<AddPaymentForm> createState() => _AddPaymentFormState();
}

class _AddPaymentFormState extends State<AddPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedMethod = 'UPI';
  String _selectedStatus = 'paid';
  bool _isSubmitting = false;

  late int _carriedPaid;
  late int _carriedRemaining;

  @override
  void initState() {
    super.initState();
    _calculateCarryForward();
    _initializeAmount();
  }

  void _calculateCarryForward() {
    final openPartials = widget.existingPayments
        .where((p) => p.status == 'partial' && p.remainingAmount > 0)
        .toList();

    if (openPartials.isEmpty) {
      _carriedPaid = 0;
      _carriedRemaining = widget.rentAmount;
      return;
    }

    openPartials.sort((a, b) => b.date.compareTo(a.date));
    final latest = openPartials.first;

    _carriedPaid = latest.paidAmount;
    _carriedRemaining = latest.remainingAmount;
  }

  void _initializeAmount() {
    final suggested = _carriedRemaining > 0
        ? _carriedRemaining
        : (widget.rentAmount > 0 ? widget.rentAmount : 0);
    if (suggested > 0) {
      _amountCtrl.text = suggested.toString();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _enteredAmount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  int _baseForStatus() {
    if (_carriedRemaining > 0 && _carriedPaid > 0) {
      return _carriedPaid + _carriedRemaining;
    }
    if (widget.rentAmount > 0) return widget.rentAmount;
    return _enteredAmount;
  }

  int _remainingAfterPartial() {
    final next = _baseForStatus() - _enteredAmount;
    return next < 0 ? 0 : next;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brandColor = OwnerDashboardColors.brandPrimary(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        child: DashboardCard(
          radius: 24,
          useGradient: true,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Payment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: brandColor.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        ),
                        border: Border.all(
                          color: brandColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Rent: Rs ${widget.rentAmount}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: brandColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_carriedPaid > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summaryCard(
                            context: context,
                            label: 'Already Paid',
                            value: 'Rs $_carriedPaid',
                            valueColor: AppTheme.successGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryCard(
                            context: context,
                            label: 'Remaining',
                            value: 'Rs $_carriedRemaining',
                            valueColor: AppTheme.warningAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Payment Status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _statusSelector(context),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _selectedStatus == 'unpaid'
                        ? 'Rent Amount Due'
                        : _selectedStatus == 'partial'
                        ? 'Installment Paid Now'
                        : 'Amount Paid',
                    prefixText: 'Rs ',
                    hintText: 'e.g., 5000',
                  ),
                  validator: (value) {
                    final amount = int.tryParse((value ?? '').trim());
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    final base = _baseForStatus();
                    if (_selectedStatus == 'partial' && amount >= base) {
                      return 'Partial payment must be less than Rs $base';
                    }
                    if (_selectedStatus == 'paid' && amount > base) {
                      return 'Amount cannot exceed Rs $base';
                    }
                    return null;
                  },
                ),
                if (_selectedStatus == 'partial') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: OwnerDashboardColors.border(context),
                      ),
                      color: brandColor.withValues(alpha: isDark ? 0.08 : 0.05),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _calcRow(
                          'Base Rent',
                          'Rs ${_baseForStatus()}',
                          textSecondary,
                        ),
                        const SizedBox(height: 6),
                        _calcRow(
                          'Paying Now',
                          'Rs $_enteredAmount',
                          brandColor,
                        ),
                        const SizedBox(height: 6),
                        _calcRow(
                          'Remaining After This',
                          'Rs ${_remainingAfterPartial()}',
                          AppTheme.warningAmber,
                          fontWeight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _inputChip(
                  context,
                  label: _dateLabel(_selectedDate),
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: OwnerDashboardColors.isDark(context)
                        ? AppColors.white.withValues(alpha: 0.06)
                        : AppColors.white.withValues(alpha: 0.92),
                    border: Border.all(
                      color: OwnerDashboardColors.border(context),
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMethod,
                    isExpanded: true,
                    menuMaxHeight: 260,
                    dropdownColor: OwnerDashboardColors.isDark(context)
                        ? const Color(0xFF1A1E2A)
                        : AppColors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: brandColor,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedItemBuilder: (context) {
                      return const ['UPI', 'Cash', 'Bank Transfer', 'Cheque']
                          .map(
                            (method) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                method,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList();
                    },
                    items: const ['UPI', 'Cash', 'Bank Transfer', 'Cheque'].map(
                      (method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(
                            method,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        );
                      },
                    ).toList(),
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: brandColor,
                        size: 20,
                      ),
                      labelStyle: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: textSecondary),
                      floatingLabelStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            color: brandColor,
                            fontWeight: FontWeight.w600,
                          ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: OwnerDashboardColors.border(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: OwnerDashboardColors.border(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: brandColor, width: 1.4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMethod = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g., installment transferred through UPI',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: brandColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: brandColor.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: AppLoadingIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Save Payment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusSelector(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    final statuses = [
      ('paid', 'Paid', AppTheme.successGreen, Icons.check_circle_rounded),
      ('partial', 'Partial', AppTheme.warningAmber, Icons.timelapse_rounded),
      ('unpaid', 'Unpaid', AppTheme.errorRed, Icons.error_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark
            ? AppColors.white.withValues(alpha: 0.05)
            : AppColors.white.withValues(alpha: 0.75),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Row(
        children: statuses.map((statusMeta) {
          final (value, label, color, icon) = statusMeta;
          final isSelected = _selectedStatus == value;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedStatus = value),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : OwnerDashboardColors.border(context),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? color.withValues(alpha: isDark ? 0.14 : 0.09)
                          : (isDark
                                ? AppColors.white.withValues(alpha: 0.01)
                                : AppColors.white.withValues(alpha: 0.55)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 15,
                          color: isSelected ? color : textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isSelected ? color : textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryCard({
    required BuildContext context,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwnerDashboardColors.border(context)),
        color: valueColor.withValues(
          alpha: OwnerDashboardColors.isDark(context) ? 0.08 : 0.04,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OwnerDashboardColors.textSecondary(context),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calcRow(
    String label,
    String value,
    Color valueColor, {
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: OwnerDashboardColors.textSecondary(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }

  Widget _inputChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OwnerDashboardColors.border(context)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final baseAmount = _baseForStatus();
    int paidAmount;

    if (_selectedStatus == 'unpaid') {
      paidAmount = 0;
    } else {
      paidAmount = _enteredAmount;
    }

    final remainingAmount = (baseAmount - paidAmount).clamp(0, baseAmount);
    final finalStatus = remainingAmount == 0
        ? (paidAmount > 0 ? 'paid' : 'unpaid')
        : (paidAmount > 0 ? 'partial' : 'unpaid');

    final notes = _notesCtrl.text.trim();

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        AddPaymentPayload(
          baseAmount: baseAmount,
          paidAmount: paidAmount,
          remainingAmount: remainingAmount,
          date: _selectedDate,
          method: _selectedMethod,
          status: finalStatus,
          notes: notes.isEmpty ? null : notes,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _dateLabel(DateTime date) {
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
}
