import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/features/payment/domain/services/tenant_payment_calculator.dart';
import 'package:rentdone/features/tenant/payment_module/models/payment_summary_model.dart';
import 'package:rentdone/features/tenant/payment_module/services/payment_providers.dart';
import 'package:rentdone/features/tenant/payment_module/widgets/payment_widgets.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  static final NumberFormat _currency = NumberFormat('#,##,##0.00', 'en_IN');

  bool _isPayingRazorpay = false;
  bool _isMarkingCash = false;

  PaymentSummaryModel? _lastSummary;

  String _inr(double value) => '₹${_currency.format(value)}';

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(paymentSummaryProvider(widget.tenantId));

    summaryAsync.whenData((summary) {
      _lastSummary = summary;
    });

    final summary = summaryAsync.asData?.value ?? _lastSummary;

    final rent = summary?.tenant?.rent ?? 0;
    final due = summary?.dueAmount ?? 0;
    final quote = TenantPaymentCalculator.calculate(
      rentAmount: due.ceil(),
      paymentMethod: TenantPaymentMethod.netbanking,
    );
    final fee = quote.convenienceFee.toDouble();
    final gstOnFee = quote.gstOnConvenienceFee.toDouble();
    final totalPayable = quote.totalPayable.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Rent Payment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (summaryAsync.isLoading && summary == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            PaymentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text('Owner ID: ${summary?.tenant?.ownerId ?? '-'}'),
                  Text('Tenant: ${summary?.tenant?.name ?? '-'}'),
                  Text('Tenant ID: ${widget.tenantId}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PaymentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Month Summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  PaymentLineItem(label: 'Monthly Rent', value: _inr(rent)),
                  PaymentLineItem(
                    label: 'Paid This Month',
                    value: _inr(summary?.totalPaidThisMonth ?? 0),
                  ),
                  const Divider(),
                  PaymentLineItem(
                    label: 'Due Amount',
                    value: _inr(due),
                    bold: true,
                  ),
                  if (summaryAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PaymentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Breakdown',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  PaymentLineItem(label: 'Due', value: _inr(due)),
                  PaymentLineItem(
                    label:
                        'Convenience Fee (${(quote.feePercentUsed * 100).toStringAsFixed(2)}%)',
                    value: _inr(fee),
                  ),
                  PaymentLineItem(
                    label:
                        'GST on Fee (${(quote.gstPercentUsed * 100).toStringAsFixed(0)}%)',
                    value: _inr(gstOnFee),
                  ),
                  const Divider(),
                  PaymentLineItem(
                    label: 'Total Payable',
                    value: _inr(totalPayable),
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PaymentPrimaryButton(
              label: 'Pay With Razorpay',
              isLoading: _isPayingRazorpay,
              onTap: totalPayable <= 0 || _isMarkingCash
                  ? null
                  : () => _payWithRazorpay(
                      dueAmount: due,
                      totalPayable: totalPayable,
                    ),
            ),
            const SizedBox(height: 10),
            PaymentSecondaryButton(
              label: 'Paid Via Cash',
              isLoading: _isMarkingCash,
              onTap: due <= 0 || _isPayingRazorpay
                  ? null
                  : () => _markPaidViaCash(due),
            ),
            const SizedBox(height: 10),
            Text(
              'Due is calculated dynamically as rent minus SUCCESS payments in current month. If data is unavailable, values safely fall back to ₹0.00.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payWithRazorpay({
    required double dueAmount,
    required double totalPayable,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please sign in to continue payment.');
      return;
    }

    setState(() => _isPayingRazorpay = true);

    try {
      final razorpayService = ref.read(tenantModuleRazorpayServiceProvider);

      final result = await razorpayService.startTenantPayment(
        tenantId: widget.tenantId,
        rentAmountInRupees: dueAmount,
        totalAmountInRupees: totalPayable,
        tenantName: _lastSummary?.tenant?.name ?? '',
        tenantEmail: user.email ?? '',
        tenantPhone: user.phoneNumber ?? '',
      );

      if (!mounted) return;

      if (result.success) {
        _showMessage('Payment successful.');
      } else {
        _showMessage(result.message ?? 'Payment failed. Please try again.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_sanitizeError(error));
    } finally {
      if (mounted) {
        setState(() => _isPayingRazorpay = false);
      }
    }
  }

  Future<void> _markPaidViaCash(double due) async {
    setState(() => _isMarkingCash = true);

    try {
      final service = ref.read(paymentServiceProvider);
      await service.markPaidViaCashPending(
        tenantId: widget.tenantId,
        amount: due,
      );

      if (!mounted) return;
      _showMessage('Cash payment marked as PENDING. Owner can confirm it.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_sanitizeError(error));
    } finally {
      if (mounted) {
        setState(() => _isMarkingCash = false);
      }
    }
  }

  String _sanitizeError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? 'Something went wrong. Please try again.' : text;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
