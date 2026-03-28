import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/owner_razorpay_payment_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/razorpay_service.dart';
import 'package:rentdone/features/owner/owner_payment/domain/exceptions/payment_exceptions.dart';
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
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 2,
  );

  StreamSubscription<PaymentState>? _paymentStateSubscription;
  StreamSubscription<PaymentResponse>? _paymentResponseSubscription;
  StreamSubscription<PaymentGatewayException>? _paymentErrorSubscription;
  bool _didHandleSuccess = false;
  bool _didNavigateFailure = false;
  OwnerRazorpayPaymentIntent? _activeIntent;
  OwnerPaymentQuote? _paymentQuote;
  bool _isQuoteLoading = true;
  String? _quoteError;
  String? _verificationFailureMessage;
  String? _lastVisibleErrorMessage;
  late final String _idempotencyKey;

  String _friendlyFunctionsError(FirebaseFunctionsException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').trim();
    final normalized = message.toLowerCase();

    if (code == 'unavailable') {
      return 'Payment backend unavailable. If testing locally, start Firebase emulators and run app with USE_FUNCTIONS_EMULATOR=true.';
    }
    if (code == 'not-found') {
      return 'Payment service not found. Deploy Cloud Functions or switch to emulator mode.';
    }
    if (code == 'resource-exhausted') {
      return 'Too many payment attempts. Please wait a minute and try again.';
    }
    if (code == 'unauthenticated') {
      return 'Session expired. Please login again and retry payment.';
    }
    if (code == 'permission-denied') {
      return 'You do not have permission for this payment.';
    }
    if (code == 'failed-precondition') {
      if (normalized.contains('email-not-verified')) {
        return 'Verify your email first, then retry payment.';
      }
      if (normalized.contains('maintenance-mode')) {
        return 'Payments are temporarily paused for maintenance.';
      }
      if (normalized.contains('payments-disabled')) {
        return 'Payments are currently disabled by admin settings.';
      }
      if (normalized.contains('razorpay-disabled')) {
        return 'Razorpay is currently disabled by admin settings.';
      }
      if (normalized.contains('razorpay mode-key mismatch')) {
        return 'Razorpay backend is in wrong mode-key combination. Switch backend to test mode with test keys.';
      }
      if (normalized.contains('keys not configured for mode') ||
          normalized.contains('secret not configured for mode')) {
        return 'Razorpay backend keys for current mode are missing. Configure test mode keys and redeploy functions.';
      }
      if (normalized.contains('tenant-link') ||
          normalized.contains('invalid-owner') ||
          normalized.contains('property-name-mismatch')) {
        return 'Tenant-property link is invalid. Reassign tenant to the correct property and retry.';
      }
    }

    return message.isEmpty
        ? 'Unable to start payment right now. Please try again.'
        : message;
  }

  @override
  void initState() {
    super.initState();
    _idempotencyKey =
        'owner_${widget.tenantId}_${widget.propertyId}_${DateTime.now().millisecondsSinceEpoch}';
    _setupPaymentListeners();
    _loadPaymentQuote();
  }

  @override
  void dispose() {
    _paymentStateSubscription?.cancel();
    _paymentResponseSubscription?.cancel();
    _paymentErrorSubscription?.cancel();
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

    _paymentErrorSubscription?.cancel();
    _paymentErrorSubscription = razorpayService.paymentErrorStream.listen((
      error,
    ) {
      if (!mounted) return;
      final message = error.message.trim();
      _navigateToFailure(
        message.isEmpty
            ? 'Payment could not be processed. Please try again.'
            : message,
      );
    });
  }

  Future<void> _loadPaymentQuote() async {
    setState(() {
      _isQuoteLoading = true;
      _quoteError = null;
    });

    try {
      final paymentGatewayService = ref.read(
        ownerRazorpayPaymentServiceProvider,
      );
      final quote = await paymentGatewayService.quotePayment(
        amount: widget.amount,
      );
      if (!mounted) return;
      setState(() {
        _paymentQuote = quote;
        _isQuoteLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteError = _friendlyFunctionsError(e);
        _isQuoteLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quoteError = 'Unable to load payment breakdown. Pull to retry.';
        _isQuoteLoading = false;
      });
    }
  }

  String _formatPaise(int paise) {
    return _currencyFormat.format(paise / 100);
  }

  int get _rentAmountInPaise =>
      _paymentQuote?.rentAmountInPaise ?? widget.amount * 100;
  int get _convenienceFeeInPaise => _paymentQuote?.convenienceFeeInPaise ?? 0;
  int get _totalPayableInPaise =>
      _paymentQuote?.totalPayableInPaise ??
      (_rentAmountInPaise + _convenienceFeeInPaise);

  Future<void> _onPaymentSuccess(PaymentResponse response) async {
    if (_didHandleSuccess) return;
    _didHandleSuccess = true;

    final saved = await _savePaymentToFirebase(response);
    if (!mounted) return;

    if (saved) {
      _handlePaymentSuccess();
    } else {
      _navigateToFailure(
        _verificationFailureMessage ??
            'Payment completed but we could not update records.',
      );
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
    _lastVisibleErrorMessage = errorMessage.trim().isEmpty
        ? 'Payment failed. Please try again.'
        : errorMessage.trim();
    if (_didNavigateFailure) return;
    _didNavigateFailure = true;
    context.go(
      '/owner/payments/failure?amount=${widget.amount}&tenantName=${Uri.encodeComponent(widget.tenantName)}&propertyName=${Uri.encodeComponent(widget.propertyName)}&error=${Uri.encodeComponent(_lastVisibleErrorMessage!)}',
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
      _verificationFailureMessage = null;
      return true;
    } on FirebaseFunctionsException catch (e) {
      _verificationFailureMessage = _friendlyFunctionsError(e);
      debugPrint('❌ Verification error: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error verifying payment: $e');
      _verificationFailureMessage =
          'Payment was successful, but verification failed. Please contact support with your transaction ID.';
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
                        onPressed: _isQuoteLoading ? null : _initiatePayment,
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
                              'Pay ${_formatPaise(_totalPayableInPaise)}',
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
                            _lastVisibleErrorMessage ??
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
              amount: (_totalPayableInPaise / 100).ceil(),
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
            _formatPaise(_rentAmountInPaise),
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
          if (_isQuoteLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_quoteError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _quoteError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadPaymentQuote,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          _summaryRow(
            context,
            'Rent Amount',
            _formatPaise(_rentAmountInPaise),
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            context,
            'Convenience Fee',
            _formatPaise(_convenienceFeeInPaise),
            leading: Tooltip(
              message: 'This fee is charged by payment providers.',
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: OwnerDashboardColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: OwnerDashboardColors.border(context)),
          const SizedBox(height: 8),
          _summaryRow(
            context,
            'Total Payable',
            _formatPaise(_totalPayableInPaise),
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    Widget? leading,
    bool highlight = false,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OwnerDashboardColors.textSecondary(context),
              ),
            ),
            if (leading != null) ...[const SizedBox(width: 6), leading],
          ],
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
    if (_isQuoteLoading) {
      return;
    }

    final paymentNotifier = ref.read(paymentStateNotifierProvider.notifier);
    final paymentGatewayService = ref.read(ownerRazorpayPaymentServiceProvider);

    late final OwnerRazorpayPaymentIntent intent;
    try {
      _verificationFailureMessage = null;
      intent = await paymentGatewayService.createPaymentIntent(
        tenantId: widget.tenantId,
        propertyId: widget.propertyId,
        amount: widget.amount,
        idempotencyKey: _idempotencyKey,
      );
      _activeIntent = intent;

      if (mounted) {
        setState(() {
          _paymentQuote = OwnerPaymentQuote(
            rentAmountInPaise: intent.rentAmountInPaise,
            convenienceFeeInPaise: intent.convenienceFeeInPaise,
            totalPayableInPaise: intent.totalPayableInPaise,
            gatewayPercent: _paymentQuote?.gatewayPercent ?? 0,
            gstPercent: _paymentQuote?.gstPercent ?? 18,
          );
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _navigateToFailure(_friendlyFunctionsError(e));
      return;
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      _navigateToFailure(
        message.isEmpty
            ? 'Unable to start payment right now. Please try again.'
            : message,
      );
      return;
    }

    final paymentRequest = PaymentRequest(
      orderId: intent.orderId,
      amount: intent.totalPayableInPaise,
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
        'rentAmountInPaise': intent.rentAmountInPaise,
        'convenienceFeeInPaise': intent.convenienceFeeInPaise,
        'totalPayableInPaise': intent.totalPayableInPaise,
        'tenantName': widget.tenantName,
        'propertyName': widget.propertyName,
      },
    );

    final initiated = await paymentNotifier.initiatePayment(
      paymentRequest: paymentRequest,
      tenantId: widget.tenantId,
      propertyId: widget.propertyId,
    );

    if (!initiated && mounted) {
      final service = ref.read(razorpayServiceProvider);
      final message = service.lastPaymentError?.message.trim() ?? '';
      _navigateToFailure(
        message.isEmpty
            ? 'Unable to start payment right now. Please try again.'
            : message,
      );
    }
  }
}

/// Riverpod provider for owner Razorpay backend service
final ownerRazorpayPaymentServiceProvider =
    Provider<OwnerRazorpayPaymentService>((ref) {
      return OwnerRazorpayPaymentService();
    });
