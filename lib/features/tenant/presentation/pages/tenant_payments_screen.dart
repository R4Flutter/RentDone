import 'dart:ui';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/payment/data/gateways/tenant_razorpay_gateway_adapter.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/services/tenant_payment_calculator.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_dashboard_provider.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_di.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

class TenantPaymentsScreen extends ConsumerStatefulWidget {
  const TenantPaymentsScreen({super.key});

  @override
  ConsumerState<TenantPaymentsScreen> createState() =>
      _TenantPaymentsScreenState();
}

class _TenantPaymentsScreenState extends ConsumerState<TenantPaymentsScreen> {
  static final NumberFormat _currency = NumberFormat('#,##,##0', 'en_IN');

  final TextEditingController _amountController = TextEditingController();

  bool _isPaying = false;
  bool _isSavingUpi = false;
  bool _isSavingRent = false;
  Timer? _processingHintTimer;
  int _processingHintIndex = 0;
  String? _lastReceipt;
  int _lastPaidAmount = 0;
  DateTime? _lastPaidAt;

  String _ownerName = 'Owner';
  String _ownerUpiId = '';
  int _monthlyRent = 0;
  String _lastHydratedTenantId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(transactionHistoryProvider.notifier)
          .loadInitial(actor: TransactionActor.tenant);
    });
  }

  @override
  void dispose() {
    _processingHintTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _startProcessingHints() {
    _processingHintTimer?.cancel();
    _processingHintIndex = 0;
    _processingHintTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_isPaying) return;
      setState(() {
        _processingHintIndex = (_processingHintIndex + 1) % 2;
      });
    });
  }

  void _stopProcessingHints() {
    _processingHintTimer?.cancel();
    _processingHintTimer = null;
    _processingHintIndex = 0;
  }

  Future<void> _showSuccessCelebration() async {
    if (!mounted || _lastPaidAmount <= 0) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SheetShell(
          title: 'Rent Paid Successfully',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OwnerDashboardColors.brandPrimary(
                      context,
                    ).withValues(alpha: 0.17),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 54,
                    color: Color(0xFF4CD37A),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Rent done. Stress gone.',
                style: TextStyle(
                  color: OwnerDashboardColors.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: ${_formatRupees(_lastPaidAmount)}',
                style: TextStyle(
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
              Text(
                'Paid on: ${DateFormat('dd MMM yyyy, hh:mm a').format(_lastPaidAt ?? DateTime.now())}',
                style: TextStyle(
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryActionButton(
                      text: 'View History',
                      onTap: () {
                        Navigator.of(context).pop();
                        this.context.push('/tenant/transactions');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PrimaryActionButton(
                      text: 'Copy Receipt',
                      onTap: () async {
                        final receipt = _lastReceipt;
                        if (receipt != null && receipt.trim().isNotEmpty) {
                          await Clipboard.setData(ClipboardData(text: receipt));
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  int get _enteredAmount => int.tryParse(_amountController.text.trim()) ?? 0;

  TenantPaymentQuote get _paymentQuote => TenantPaymentCalculator.calculate(
    rentAmount: _enteredAmount,
    paymentMethod: TenantPaymentMethod.netbanking,
  );

  String _formatRupees(int amount) => '\u20B9${_currency.format(amount)}';

  void _hydrateFromState({
    required TenantDashboardSummary summary,
    required TenantOwnerDetails? owner,
    required TenantRoomDetails? room,
    required PaymentDashboardState? paymentState,
  }) {
    final resolvedOwnerName = (owner?.ownerName ?? '').trim();
    final resolvedUpi = (owner?.ownerUpiId ?? '').trim();
    final resolvedRent =
        paymentState?.due?.monthlyRent ??
        room?.monthlyRent ??
        summary.monthlyRent;

    final isSameTenant = _lastHydratedTenantId == summary.tenantId;
    final shouldRefreshOwnerName =
        resolvedOwnerName.isNotEmpty && _ownerName.trim().isEmpty;
    final shouldRefreshUpi = resolvedUpi.isNotEmpty && _ownerUpiId.isEmpty;
    final shouldRefreshRent =
        resolvedRent > 0 && (_monthlyRent <= 0 || _monthlyRent != resolvedRent);
    final currentEntered = int.tryParse(_amountController.text.trim());
    final shouldRefreshAmount =
        resolvedRent > 0 &&
        (_amountController.text.trim().isEmpty ||
            currentEntered == null ||
            currentEntered == _monthlyRent);

    if (isSameTenant &&
        !shouldRefreshOwnerName &&
        !shouldRefreshUpi &&
        !shouldRefreshRent &&
        !shouldRefreshAmount) {
      return;
    }

    if (resolvedOwnerName.isNotEmpty) {
      _ownerName = resolvedOwnerName;
    }
    if (resolvedUpi.isNotEmpty) {
      _ownerUpiId = resolvedUpi;
    }
    if (resolvedRent > 0) {
      _monthlyRent = resolvedRent;
      if (_amountController.text.trim().isEmpty) {
        _amountController.text = resolvedRent.toString();
      }
    }

    _lastHydratedTenantId = summary.tenantId;
  }

  Future<void> _startPayment() async {
    if (_isPaying || _enteredAmount <= 0) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isPaying = true);
    _startProcessingHints();

    final messenger = ScaffoldMessenger.of(context);

    await ref.read(paymentDashboardProvider.notifier).refreshDue();
    final due = ref.read(paymentDashboardProvider).asData?.value.due;
    if (due == null) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Current due is still loading. Please refresh and try again.',
            ),
          ),
        );
        setState(() => _isPaying = false);
        _stopProcessingHints();
      }
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Processing payment...')),
    );

    try {
      final gateway = TenantRazorpayGatewayAdapter(
        ref.read(razorpayServiceProvider),
      );

      final intent = await ref
          .read(paymentDashboardProvider.notifier)
          .createAndPay(
            gateway: 'razorpay',
            paymentGateway: gateway,
            tenantEmail: user.email ?? '',
            tenantPhone: user.phoneNumber ?? '',
          );

      if (!mounted) {
        return;
      }

      if (intent != null) {
        await ref.read(paymentDashboardProvider.notifier).refreshDue();
        await ref.read(transactionHistoryProvider.notifier).refresh();

        final receipt = [
          'TenantPay Receipt',
          'Amount Paid: ${_formatRupees((intent.totalPayableInPaise / 100).ceil())}',
          'Transaction ID: ${intent.paymentId}',
          'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
        ].join('\n');

        await Clipboard.setData(ClipboardData(text: receipt));
        _lastReceipt = receipt;
        _lastPaidAmount = (intent.totalPayableInPaise / 100).ceil();
        _lastPaidAt = DateTime.now();

        if (!mounted) {
          return;
        }

        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment successful. Receipt copied to clipboard.'),
          ),
        );
        await _showSuccessCelebration();
        return;
      }

      final message =
          ref.read(paymentDashboardProvider).asData?.value.message ??
          'Payment failed. Please try again.';

      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on PaymentFailure catch (failure) {
      if (!mounted) {
        return;
      }
      final message = failure.message.trim().isEmpty
          ? 'Payment failed. Please try again.'
          : failure.message.trim();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final raw = error.toString().replaceFirst('Exception: ', '').trim();
      final message = raw.isEmpty
          ? (ref.read(paymentDashboardProvider).asData?.value.message ??
                'Payment failed. Please try again.')
          : raw;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _stopProcessingHints();
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  Future<void> _showEditUpiModal({
    required String tenantId,
    required TenantDashboardSummary summary,
    required TenantOwnerDetails? currentOwner,
  }) async {
    final controller = TextEditingController(text: _ownerUpiId);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SheetShell(
          title: 'Update UPI ID',
          child: Column(
            children: [
              TextField(
                controller: controller,
                style: TextStyle(
                  color: OwnerDashboardColors.textPrimary(context),
                ),
                decoration: _PaymentsTheme.inputDecoration(
                  context,
                  label: 'UPI ID',
                  hint: 'name@bank',
                ),
              ),
              const SizedBox(height: 12),
              _PrimaryActionButton(
                text: _isSavingUpi ? 'Saving...' : 'Save',
                onTap: _isSavingUpi
                    ? null
                    : () async {
                        final value = controller.text.trim();
                        if (value.isEmpty) {
                          return;
                        }

                        Navigator.of(context).pop();
                        setState(() => _isSavingUpi = true);

                        try {
                          await ref
                              .read(tenantDashboardRepositoryProvider)
                              .saveOwnerDetails(
                                tenantId: tenantId,
                                details: TenantOwnerDetails(
                                  ownerPhoneNumber:
                                      currentOwner?.ownerPhoneNumber ??
                                      summary.ownerPhoneNumber,
                                  ownerName:
                                      currentOwner?.ownerName ?? _ownerName,
                                  ownerUpiId: value,
                                ),
                              );

                          ref.invalidate(tenantOwnerDetailsProvider(tenantId));
                          setState(() => _ownerUpiId = value);
                        } finally {
                          if (mounted) {
                            setState(() => _isSavingUpi = false);
                          }
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditRentModal({
    required String tenantId,
    required TenantDashboardSummary summary,
    required TenantRoomDetails? currentRoom,
  }) async {
    final controller = TextEditingController(
      text: _monthlyRent > 0 ? _monthlyRent.toString() : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SheetShell(
          title: 'Update Rent Amount',
          child: Column(
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: OwnerDashboardColors.textPrimary(context),
                ),
                decoration: _PaymentsTheme.inputDecoration(
                  context,
                  label: 'Monthly Rent',
                  hint: '15000',
                ),
              ),
              const SizedBox(height: 12),
              _PrimaryActionButton(
                text: _isSavingRent ? 'Saving...' : 'Save',
                onTap: _isSavingRent
                    ? null
                    : () async {
                        final parsed = int.tryParse(controller.text.trim());
                        if (parsed == null || parsed <= 0) {
                          return;
                        }

                        Navigator.of(context).pop();
                        setState(() => _isSavingRent = true);

                        try {
                          await ref
                              .read(tenantDashboardRepositoryProvider)
                              .saveRoomDetails(
                                tenantId: tenantId,
                                details: TenantRoomDetails(
                                  propertyName:
                                      currentRoom?.propertyName.isNotEmpty ==
                                          true
                                      ? currentRoom!.propertyName
                                      : summary.propertyName,
                                  roomNumber:
                                      currentRoom?.roomNumber.isNotEmpty == true
                                      ? currentRoom!.roomNumber
                                      : summary.roomNumber,
                                  monthlyRent: parsed,
                                  depositAmount:
                                      currentRoom?.depositAmount ??
                                      summary.depositAmount,
                                  allocationDate:
                                      currentRoom?.allocationDate ??
                                      summary.allocationDate ??
                                      DateTime.now(),
                                  rentDueDay:
                                      currentRoom?.rentDueDay ??
                                      summary.rentDueDay,
                                ),
                              );

                          ref.invalidate(tenantRoomDetailsProvider(tenantId));
                          ref.invalidate(tenantDashboardProvider);
                          setState(() {
                            _monthlyRent = parsed;
                            _amountController.text = parsed.toString();
                          });
                        } finally {
                          if (mounted) {
                            setState(() => _isSavingRent = false);
                          }
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);
    final paymentAsync = ref.watch(paymentDashboardProvider);
    final txAsync = ref.watch(transactionHistoryProvider);

    return summaryAsync.when(
      loading: () => _PageScaffold(
        child: Center(
          child: AppLoadingIndicator(
            color: OwnerDashboardColors.brandPrimary(context),
          ),
        ),
      ),
      error: (_, _) => _PageScaffold(
        child: Center(
          child: Text(
            'Unable to load payments',
            style: TextStyle(color: OwnerDashboardColors.textPrimary(context)),
          ),
        ),
      ),
      data: (summary) {
        final tenantId = summary.tenantId;
        final ownerAsync = tenantId.isEmpty
            ? const AsyncValue<TenantOwnerDetails?>.data(null)
            : ref.watch(tenantOwnerDetailsProvider(tenantId));
        final roomAsync = tenantId.isEmpty
            ? const AsyncValue<TenantRoomDetails?>.data(null)
            : ref.watch(tenantRoomDetailsProvider(tenantId));

        final owner = ownerAsync.asData?.value;
        final room = roomAsync.asData?.value;
        final paymentState = paymentAsync.asData?.value;
        final flowStatus = paymentState?.flowStatus ?? PaymentFlowStatus.idle;
        final txState = txAsync.asData?.value;
        final latestTx = txState?.transactions.isNotEmpty == true
            ? txState!.transactions.first
            : null;
        final dueAmount = paymentState?.due?.totalPayable ?? _enteredAmount;
        final isOverdue =
            dueAmount > 0 && DateTime.now().day > summary.rentDueDay;
        final dueStatus = dueAmount <= 0
            ? 'Paid'
            : (isOverdue ? 'Overdue' : 'Due');

        _hydrateFromState(
          summary: summary,
          owner: owner,
          room: room,
          paymentState: paymentState,
        );

        return _PageScaffold(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pay Rent',
                      style: TextStyle(
                        color: OwnerDashboardColors.textPrimary(context),
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/tenant/transactions'),
                    style: TextButton.styleFrom(
                      foregroundColor: OwnerDashboardColors.textPrimary(
                        context,
                      ),
                    ),
                    child: const Text('History'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Current Status',
                          style: TextStyle(
                            color: OwnerDashboardColors.textSecondary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        _StatusPill(
                          text: dueStatus,
                          color: dueStatus == 'Paid'
                              ? const Color(0xFF3BCB72)
                              : dueStatus == 'Overdue'
                              ? const Color(0xFFFF6B6B)
                              : OwnerDashboardColors.brandPrimary(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rent due: ${_formatRupees(dueAmount)}',
                      style: TextStyle(
                        color: OwnerDashboardColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Due day ${summary.rentDueDay} of every month',
                      style: TextStyle(
                        color: OwnerDashboardColors.textSecondary(context),
                      ),
                    ),
                    if (latestTx != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last payment: ${_formatRupees(latestTx.amount.toInt())} on ${DateFormat('dd MMM').format(latestTx.completedAt ?? latestTx.createdAt)}',
                        style: TextStyle(
                          color: OwnerDashboardColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _GlassCard(
                child: _InfoCardContent(
                  title: 'Owner Details',
                  line1: _ownerName,
                  line2: _ownerUpiId.isEmpty ? 'UPI not set' : _ownerUpiId,
                  actionText: 'Edit UPI',
                  onAction: summary.tenantId.isEmpty
                      ? null
                      : () => _showEditUpiModal(
                          tenantId: summary.tenantId,
                          summary: summary,
                          currentOwner: owner,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              _GlassCard(
                child: _InfoCardContent(
                  title: 'Monthly Rent',
                  line1: _formatRupees(_monthlyRent),
                  line2: 'Due day: ${summary.rentDueDay}',
                  actionText: 'Edit Rent',
                  onAction: summary.tenantId.isEmpty
                      ? null
                      : () => _showEditRentModal(
                          tenantId: summary.tenantId,
                          summary: summary,
                          currentRoom: room,
                        ),
                ),
              ),
              const SizedBox(height: 10),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Amount',
                      style: TextStyle(
                        color: OwnerDashboardColors.textSecondary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: OwnerDashboardColors.textPrimary(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: _PaymentsTheme.inputDecoration(
                        context,
                        label: 'Amount',
                        hint: _monthlyRent > 0 ? _monthlyRent.toString() : '0',
                      ).copyWith(prefixText: '\u20B9 '),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Breakdown',
                      style: TextStyle(
                        color: OwnerDashboardColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _BreakdownRow(
                      label: 'Rent',
                      value: _formatRupees(_enteredAmount),
                    ),
                    _BreakdownRow(
                      label:
                          'Convenience Fee (${(_paymentQuote.feePercentUsed * 100).toStringAsFixed(2)}%)',
                      value: _formatRupees(_paymentQuote.convenienceFee),
                    ),
                    _BreakdownRow(
                      label:
                          'GST on Fee (${(_paymentQuote.gstPercentUsed * 100).toStringAsFixed(0)}%)',
                      value: _formatRupees(_paymentQuote.gstOnConvenienceFee),
                    ),
                    Divider(color: OwnerDashboardColors.border(context)),
                    _BreakdownRow(
                      label: 'Total Payable',
                      value: _formatRupees(_paymentQuote.totalPayable),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_isPaying)
                _GlassCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: AppLoadingIndicator(
                          strokeWidth: 2.2,
                          color: OwnerDashboardColors.brandPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: Text(
                            key: ValueKey(_processingHintIndex),
                            _processingHintIndex == 0
                                ? 'Processing securely...'
                                : 'Almost done...',
                            style: TextStyle(
                              color: OwnerDashboardColors.textSecondary(
                                context,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isPaying) const SizedBox(height: 10),
              _GlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: OwnerDashboardColors.brandPrimary(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Secure payment via Razorpay. Small gateway fee ensures fast and protected transactions.',
                        style: TextStyle(
                          color: OwnerDashboardColors.textSecondary(context),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _GlassCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _TrustBadge(text: 'Razorpay Verified'),
                    _TrustBadge(text: 'Owner Notified Instantly'),
                    _TrustBadge(text: 'Receipt Available'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _PrimaryActionButton(
                text: _isPaying ? 'Processing...' : 'Pay Now',
                onTap: (_enteredAmount <= 0 || _isPaying)
                    ? null
                    : _startPayment,
              ),
              const SizedBox(height: 8),
              if (paymentState?.message != null)
                Text(
                  paymentState!.message!,
                  style: TextStyle(
                    color: OwnerDashboardColors.textSecondary(context),
                  ),
                ),
              if (flowStatus == PaymentFlowStatus.pendingVerification) ...[
                const SizedBox(height: 8),
                _PrimaryActionButton(
                  text: 'Check Payment Status',
                  onTap: () async {
                    await ref
                        .read(paymentDashboardProvider.notifier)
                        .refreshDue();
                    await ref
                        .read(transactionHistoryProvider.notifier)
                        .refresh();
                  },
                ),
              ],
              if (flowStatus == PaymentFlowStatus.failure) ...[
                const SizedBox(height: 8),
                _PrimaryActionButton(
                  text: 'Retry Payment',
                  onTap: _isPaying ? null : _startPayment,
                ),
              ],
              if (txAsync.isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    color: OwnerDashboardColors.brandPrimary(context),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final String text;

  const _TrustBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: OwnerDashboardColors.elevatedBackground(
          context,
        ).withValues(alpha: 0.88),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: OwnerDashboardColors.textSecondary(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PaymentsTheme {
  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: OwnerDashboardColors.textSecondary(context)),
      hintStyle: TextStyle(color: OwnerDashboardColors.textMuted(context)),
      filled: true,
      fillColor: OwnerDashboardColors.elevatedBackground(
        context,
      ).withValues(alpha: 0.82),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: OwnerDashboardColors.border(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: OwnerDashboardColors.brandPrimary(context),
          width: 1.25,
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final Widget child;

  const _PageScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final topBlob = OwnerDashboardColors.ownerTopBlobColor(context);
    final bottomBlob = OwnerDashboardColors.ownerBottomBlobColor(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: OwnerDashboardColors.ownerPageBackgroundGradient(context),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -80,
              top: -60,
              child: _Blob(color: topBlob, size: 220),
            ),
            Positioned(
              right: -90,
              bottom: -90,
              child: _Blob(color: bottomBlob, size: 240),
            ),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.62), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final border = OwnerDashboardColors.border(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                      OwnerDashboardColors.cardBackground(context),
                      Colors.white,
                      0.05,
                    ) ??
                    OwnerDashboardColors.cardBackground(context),
                Color.lerp(
                      OwnerDashboardColors.elevatedBackground(context),
                      OwnerDashboardColors.brandPrimary(context),
                      0.08,
                    ) ??
                    OwnerDashboardColors.elevatedBackground(context),
              ],
            ),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _PrimaryActionButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: OwnerDashboardColors.brandPrimary(context),
          foregroundColor: Colors.white,
          disabledBackgroundColor: OwnerDashboardColors.brandPrimary(
            context,
          ).withValues(alpha: 0.46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _InfoCardContent extends StatelessWidget {
  final String title;
  final String line1;
  final String line2;
  final String actionText;
  final VoidCallback? onAction;

  const _InfoCardContent({
    required this.title,
    required this.line1,
    required this.line2,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: OwnerDashboardColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(onPressed: onAction, child: Text(actionText)),
          ],
        ),
        Text(
          line1,
          style: TextStyle(color: OwnerDashboardColors.textPrimary(context)),
        ),
        const SizedBox(height: 4),
        Text(
          line2,
          style: TextStyle(color: OwnerDashboardColors.textSecondary(context)),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: OwnerDashboardColors.textSecondary(context),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: OwnerDashboardColors.textPrimary(context),
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: OwnerDashboardColors.cardBackground(context),
          border: Border.all(color: OwnerDashboardColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: OwnerDashboardColors.textPrimary(context),
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
