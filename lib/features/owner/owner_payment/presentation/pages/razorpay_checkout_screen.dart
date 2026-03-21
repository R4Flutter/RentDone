import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/owner_razorpay_payment_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/razorpay_service.dart';
import 'package:rentdone/features/owner/owner_payment/models/payment_state.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/payment_processing_overlay.dart';
import 'package:rentdone/shared/widgets/back_handler.dart';

/// Razorpay payment checkout screen with PopScope back button control
class RazorpayCheckoutScreen extends ConsumerStatefulWidget {
  const RazorpayCheckoutScreen({
    super.key,
    required this.tenantId,
    required this.tenantName,
    required this.propertyId,
    required this.propertyName,
    required this.amount,
  });

  final String tenantId;
  final String tenantName;
  final String propertyId;
  final String propertyName;
  final int amount; // in Rupees

  @override
  ConsumerState<RazorpayCheckoutScreen> createState() =>
      _RazorpayCheckoutScreenState();
}

class _RazorpayCheckoutScreenState
    extends ConsumerState<RazorpayCheckoutScreen> {
  StreamSubscription<PaymentState>? _paymentStateSubscription;
  StreamSubscription<PaymentResponse>? _paymentResponseSubscription;
  bool _didHandleSuccess = false;
  bool _didNavigateFailure = false;
  OwnerRazorpayPaymentIntent? _activeIntent;

  @override
  void initState() {
    super.initState();
    _setupPaymentListeners();
  }

  @override
  void dispose() {
    _paymentStateSubscription?.cancel();
    _paymentResponseSubscription?.cancel();
    super.dispose();
  }

  void _setupPaymentListeners() {
    final razorpayService = ref.read(razorpayServiceProvider);

    _paymentStateSubscription?.cancel();
    _paymentStateSubscription = razorpayService.paymentStateStream.listen((
      state,
    ) {
      debugPrint('💰 Payment State: $state');

      switch (state) {
        case PaymentState.idle:
          break;
        case PaymentState.processing:
          _didHandleSuccess = false;
          _didNavigateFailure = false;
          break;
        case PaymentState.success:
          break;
        case PaymentState.failed:
          if (mounted) {
            _navigateToFailure(
              'Payment could not be processed. Please try again.',
            );
          }
          break;
        case PaymentState.cancelled:
          if (mounted) {
            _showErrorSnackbar('Payment Cancelled', 'No amount was charged');
          }
          break;
      }
    });

    _paymentResponseSubscription?.cancel();
    _paymentResponseSubscription = razorpayService.paymentResponseStream.listen(
      (response) {
        if (response.isSuccess) {
          _onPaymentSuccess(response);
        } else if (mounted) {
          _navigateToFailure(
            response.error ?? 'Payment failed. Please try again.',
          );
        }
      },
    );
  }

  Future<void> _onPaymentSuccess(PaymentResponse response) async {
    if (_didHandleSuccess) return;
    _didHandleSuccess = true;

    final saved = await _savePaymentToFirebase(response);
    if (!mounted) return;

    if (saved) {
      _handlePaymentSuccess();
    } else {
      _navigateToFailure('Payment completed but we could not update records.');
    }
  }

  void _handlePaymentSuccess() {
    _showSuccessSnackbar(
      'Payment Successful!',
      'Your payment has been processed',
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        context.go(
          '/owner/payments/success?amount=${widget.amount}&tenantName=${Uri.encodeComponent(widget.tenantName)}&propertyName=${Uri.encodeComponent(widget.propertyName)}',
        );
      }
    });
  }

  void _navigateToFailure(String errorMessage) {
    if (_didNavigateFailure) return;
    _didNavigateFailure = true;
    context.go(
      '/owner/payments/failure?amount=${widget.amount}&tenantName=${Uri.encodeComponent(widget.tenantName)}&propertyName=${Uri.encodeComponent(widget.propertyName)}&error=${Uri.encodeComponent(errorMessage)}',
    );
  }

  Future<bool> _savePaymentToFirebase(PaymentResponse response) async {
    try {
      final paymentIntent = _activeIntent;
      if (paymentIntent == null) {
        debugPrint('❌ No active payment intent found for verification');
        return false;
      }

      if (response.transactionId.trim().isEmpty ||
          response.orderId.trim().isEmpty ||
          response.signature.trim().isEmpty) {
        debugPrint('❌ Invalid Razorpay callback payload for verification');
        return false;
      }

      final verifyService = ref.read(ownerRazorpayPaymentServiceProvider);
      await verifyService.verifyPayment(
        paymentId: paymentIntent.paymentId,
        orderId: response.orderId,
        razorpayPaymentId: response.transactionId,
        signature: response.signature,
      );

      debugPrint('✅ Payment verified and finalized via backend');
      return true;
    } catch (e) {
      debugPrint('❌ Error verifying payment: $e');
      return false;
    }
  }

  void _showSuccessSnackbar(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackbar(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentStateNotifierProvider);

    return BackHandler.sensitive(
      isCriticalInProgress: paymentState == PaymentState.processing,
      dialogTitle: 'Interrupt Payment?',
      dialogMessage: 'Going back may interrupt the process. Continue?',
      confirmText: 'Continue',
      cancelText: 'Stay',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Payment'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPaymentDetailsCard(context),
                  const SizedBox(height: 20),
                  _buildTenantInfoCard(context),
                  const SizedBox(height: 20),
                  _buildAmountSummaryCard(context),
                  const SizedBox(height: 24),

                  if (paymentState == PaymentState.idle)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _initiatePayment,
                        style: FilledButton.styleFrom(
                          backgroundColor: OwnerDashboardColors.brandPrimary(
                            context,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.credit_card_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Pay Rs ${widget.amount}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (paymentState == PaymentState.failed)
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          FilledButton(
                            onPressed: _initiatePayment,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.warningAmber,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              'Retry Payment',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Payment failed. Please try again.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  _buildSecurityInfo(context),
                ],
              ),
            ),

            PaymentProcessingOverlay(
              isVisible: paymentState == PaymentState.processing,
              amount: widget.amount,
              message: 'Processing Payment...',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsCard(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwnerDashboardColors.border(context)),
        color: OwnerDashboardColors.brandPrimary(
          context,
        ).withValues(alpha: isDark ? 0.08 : 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Amount',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OwnerDashboardColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rs ${widget.amount}',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: OwnerDashboardColors.brandPrimary(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantInfoCard(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwnerDashboardColors.border(context)),
        color: OwnerDashboardColors.textPrimary(
          context,
        ).withValues(alpha: isDark ? 0.03 : 0.01),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                widget.tenantName[0].toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OwnerDashboardColors.brandPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tenantName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.propertyName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: OwnerDashboardColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSummaryCard(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwnerDashboardColors.border(context)),
        color: OwnerDashboardColors.textPrimary(
          context,
        ).withValues(alpha: isDark ? 0.02 : 0.005),
      ),
      child: Column(
        children: [
          _summaryRow(
            context,
            'Amount',
            'Rs ${widget.amount}',
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          Divider(color: OwnerDashboardColors.border(context)),
          const SizedBox(height: 8),
          _summaryRow(context, 'Total', 'Rs ${widget.amount}', highlight: true),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OwnerDashboardColors.textSecondary(context),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: fontWeight,
            color: highlight
                ? OwnerDashboardColors.brandPrimary(context)
                : OwnerDashboardColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.successGreen.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_rounded,
            color: AppTheme.successGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your payment is secured by Razorpay',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    final paymentNotifier = ref.read(paymentStateNotifierProvider.notifier);
    final paymentGatewayService = ref.read(ownerRazorpayPaymentServiceProvider);
    final idempotencyKey =
        'owner_${widget.tenantId}_${DateTime.now().millisecondsSinceEpoch}';

    late final OwnerRazorpayPaymentIntent intent;
    try {
      intent = await paymentGatewayService.createPaymentIntent(
        tenantId: widget.tenantId,
        propertyId: widget.propertyId,
        amount: widget.amount,
        idempotencyKey: idempotencyKey,
      );
      _activeIntent = intent;
    } catch (e) {
      if (!mounted) return;
      _navigateToFailure('Unable to start payment. Please try again.');
      return;
    }

    final paymentRequest = PaymentRequest(
      orderId: intent.orderId,
      amount: intent.amountInPaise,
      currency: intent.currency,
      key: intent.keyId,
      description: 'Rent payment for ${widget.tenantName}',
      email: 'owner@rentdone.app',
      phone: '+919999999999',
      metadata: {
        'paymentId': intent.paymentId,
        'idempotencyKey': intent.idempotencyKey,
        'tenantId': widget.tenantId,
        'propertyId': widget.propertyId,
        'tenantName': widget.tenantName,
        'propertyName': widget.propertyName,
      },
    );

    await paymentNotifier.initiatePayment(
      paymentRequest: paymentRequest,
      tenantId: widget.tenantId,
      propertyId: widget.propertyId,
    );
  }
}

/// Riverpod provider for owner Razorpay backend service
final ownerRazorpayPaymentServiceProvider =
    Provider<OwnerRazorpayPaymentService>((ref) {
      return OwnerRazorpayPaymentService();
    });
