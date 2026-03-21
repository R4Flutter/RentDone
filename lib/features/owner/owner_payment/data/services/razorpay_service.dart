import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:rentdone/features/owner/owner_payment/domain/exceptions/payment_exceptions.dart';
import 'package:rentdone/features/owner/owner_payment/models/payment_state.dart';

/// Service for handling Razorpay payment operations with production-ready error handling
class RazorpayService {
  RazorpayService({required this.razorpayKey}) {
    _initializeRazorpay();
  }

  final String razorpayKey;
  late final Razorpay _razorpay;
  Completer<PaymentResponse>? _checkoutCompleter;
  String? _activeOrderId;

  // Prevent multiple simultaneous payment requests
  bool _isPaymentInProgress = false;

  // Timeout for payment operations (5 minutes)
  static const paymentTimeout = Duration(minutes: 5);

  // Stream for payment state changes
  final _paymentStateController = StreamController<PaymentState>.broadcast();

  // Stream for payment responses
  final _paymentResponseController =
      StreamController<PaymentResponse>.broadcast();

  // Stream for error messages
  final _paymentErrorController =
      StreamController<PaymentGatewayException>.broadcast();

  Stream<PaymentState> get paymentStateStream => _paymentStateController.stream;
  Stream<PaymentResponse> get paymentResponseStream =>
      _paymentResponseController.stream;
  Stream<PaymentGatewayException> get paymentErrorStream =>
      _paymentErrorController.stream;

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    if (razorpayKey.isEmpty) {
      debugPrint('⚠️ RAZORPAY_KEY not set. Payments will fail.');
    } else {
      debugPrint('🔵 Razorpay initialized successfully');
    }
  }

  /// Initiate payment with validation, timeout, and error handling
  /// Returns true if payment was initiated, false if already in progress
  /// Throws PaymentGatewayException on errors
  Future<bool> initiatePayment({
    required PaymentRequest paymentRequest,
    required String tenantId,
    required String propertyId,
  }) async {
    // Prevent duplicate payment attempts
    if (_isPaymentInProgress) {
      _paymentErrorController.add(
        PaymentGatewayException(
          message:
              'Payment already in progress. Please wait or close and try again.',
          code: 'PAYMENT_IN_PROGRESS',
        ),
      );
      return false;
    }

    // Validate request
    if (paymentRequest.orderId.isEmpty || paymentRequest.amount <= 0) {
      final error = PaymentGatewayException.checkoutFailed(null);
      _paymentErrorController.add(error);
      _paymentStateController.add(PaymentState.failed);
      return false;
    }

    try {
      _isPaymentInProgress = true;
      _paymentStateController.add(PaymentState.processing);

      debugPrint('💳 Initiating Razorpay payment:');
      debugPrint('   Order ID: ${paymentRequest.orderId}');
      debugPrint('   Amount: ${paymentRequest.amount} paise');
      debugPrint('   Tenant: $tenantId');
      debugPrint('   Property: $propertyId');

      // Wrap checkout in timeout to prevent hung states
      await _openCheckout(paymentRequest).timeout(
        paymentTimeout,
        onTimeout: () {
          throw PaymentGatewayException.timeout();
        },
      );

      return true;
    } on PaymentGatewayException catch (e) {
      debugPrint('❌ Payment gateway error: ${e.message}');
      _paymentErrorController.add(e);
      _paymentStateController.add(PaymentState.failed);
      _isPaymentInProgress = false;
      return false;
    } catch (e) {
      debugPrint('❌ Payment initiation failed: $e');
      final error = PaymentGatewayException.checkoutFailed(
        e is Exception ? e : Exception(e.toString()),
      );
      _paymentErrorController.add(error);
      _paymentStateController.add(PaymentState.failed);
      _isPaymentInProgress = false;
      return false;
    }
  }

  /// Open Razorpay checkout with timeout and error handling
  Future<void> _openCheckout(PaymentRequest request) async {
    if (request.key.trim().isEmpty) {
      throw PaymentGatewayException(
        message: 'Payment key not configured. Contact support.',
        code: 'NO_KEY',
      );
    }

    if (_checkoutCompleter != null &&
        !(_checkoutCompleter?.isCompleted ?? true)) {
      throw PaymentGatewayException(
        message: 'A payment checkout is already active.',
        code: 'CHECKOUT_ACTIVE',
      );
    }

    _checkoutCompleter = Completer<PaymentResponse>();
    _activeOrderId = request.orderId;

    try {
      final options = <String, dynamic>{
        'key': request.key,
        'amount': request.amount,
        'currency': request.currency,
        'name': 'RentDone',
        'description': request.description ?? 'Rent payment',
        'order_id': request.orderId,
        'prefill': {
          'contact': request.phone ?? '',
          'email': request.email ?? '',
        },
        'notes': request.metadata ?? const <String, dynamic>{},
      };

      _razorpay.open(options);
      await _checkoutCompleter!.future;
    } catch (e) {
      if (e is PaymentGatewayException) {
        rethrow;
      }
      throw PaymentGatewayException.checkoutFailed(
        e is Exception ? e : Exception(e.toString()),
      );
    } finally {
      _activeOrderId = null;
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    final transactionId = (response.paymentId ?? '').trim();
    final orderId = (response.orderId ?? _activeOrderId ?? '').trim();
    final signature = (response.signature ?? '').trim();

    if (transactionId.isEmpty || orderId.isEmpty || signature.isEmpty) {
      final error = PaymentGatewayException.checkoutFailed(
        Exception('Incomplete Razorpay success payload.'),
      );
      _paymentErrorController.add(error);
      _paymentStateController.add(PaymentState.failed);
      _isPaymentInProgress = false;
      _completeCheckoutWithError(error);
      return;
    }

    final paymentResponse = PaymentResponse(
      transactionId: transactionId,
      orderId: orderId,
      signature: signature,
    );

    _handlePaymentSuccess(paymentResponse);
    _completeCheckoutWithSuccess(paymentResponse);
  }

  void _onPaymentError(PaymentFailureResponse response) {
    final code = (response.code ?? -1).toString();
    final message = (response.message ?? 'Payment failed').trim();
    handlePaymentError(code, message);

    final classified = _classifyPaymentError(code, message);
    _completeCheckoutWithError(classified);
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    final wallet = (response.walletName ?? '').trim();
    if (wallet.isNotEmpty) {
      handleExternalWallet(wallet);
    }
  }

  void _completeCheckoutWithSuccess(PaymentResponse response) {
    final completer = _checkoutCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
    _checkoutCompleter = null;
  }

  void _completeCheckoutWithError(PaymentGatewayException error) {
    final completer = _checkoutCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
    _checkoutCompleter = null;
  }

  /// Handle successful payment response
  void _handlePaymentSuccess(PaymentResponse response) {
    debugPrint('✅ Payment successful:');
    debugPrint('   Transaction ID: ${response.transactionId}');
    debugPrint('   Order ID: ${response.orderId}');

    _paymentStateController.add(PaymentState.success);
    _paymentResponseController.add(response);
    _isPaymentInProgress = false;
  }

  /// Handle payment error with proper classification
  void handlePaymentError(String errorCode, String errorMessage) {
    debugPrint('❌ Payment error:');
    debugPrint('   Code: $errorCode');
    debugPrint('   Message: $errorMessage');

    // Classify error for better UX
    final classified = _classifyPaymentError(errorCode, errorMessage);

    final response = PaymentResponse(
      transactionId: '',
      orderId: '',
      signature: '',
      error: classified.message,
      errorCode: classified.code,
    );

    _paymentErrorController.add(classified);
    _paymentStateController.add(PaymentState.failed);
    _paymentResponseController.add(response);
    _isPaymentInProgress = false;
  }

  /// Classify Razorpay errors into user-friendly messages
  PaymentGatewayException _classifyPaymentError(
    String errorCode,
    String errorMessage,
  ) {
    // Map Razorpay error codes to custom exceptions
    if (errorCode.contains('insufficient') ||
        errorMessage.contains('insufficient')) {
      return PaymentGatewayException.insufficientFunds();
    } else if (errorCode.contains('invalid_card') ||
        errorMessage.contains('card')) {
      return PaymentGatewayException.invalidCard();
    } else if (errorCode.contains('timeout') ||
        errorMessage.contains('timeout')) {
      return PaymentGatewayException.timeout();
    } else if (errorCode.contains('cancelled') ||
        errorMessage.contains('cancelled')) {
      return PaymentGatewayException.userCancelled();
    }
    return PaymentGatewayException.checkoutFailed(null);
  }

  /// Handle external wallet selection (Google Pay, Apple Pay, etc.)
  void handleExternalWallet(String walletName) {
    debugPrint('💳 External wallet selected: $walletName');
    // User selected external wallet, let Razorpay handle it
  }

  /// Reset payment state for next transaction
  void reset() {
    _isPaymentInProgress = false;
    _paymentStateController.add(PaymentState.idle);
  }

  /// Cancel payment in progress
  void cancelPayment() {
    if (_isPaymentInProgress) {
      _paymentErrorController.add(PaymentGatewayException.userCancelled());
      _paymentStateController.add(PaymentState.cancelled);
      _isPaymentInProgress = false;
    }
  }

  /// Cleanup resources
  void dispose() {
    if (_checkoutCompleter != null &&
        !(_checkoutCompleter?.isCompleted ?? true)) {
      _completeCheckoutWithError(PaymentGatewayException.userCancelled());
    }
    _razorpay.clear();
    _paymentStateController.close();
    _paymentResponseController.close();
    _paymentErrorController.close();
  }
}

/// Riverpod provider for Razorpay service
final razorpayServiceProvider = Provider<RazorpayService>((ref) {
  const key = String.fromEnvironment('RAZORPAY_KEY', defaultValue: '');

  final service = RazorpayService(razorpayKey: key);

  // Cleanup on disposal
  ref.onDispose(service.dispose);

  return service;
});

/// Notifier for payment state
class PaymentNotifier extends Notifier<PaymentState> {
  StreamSubscription<PaymentState>? _stateSubscription;

  RazorpayService get _razorpayService => ref.read(razorpayServiceProvider);

  @override
  PaymentState build() {
    _stateSubscription?.cancel();
    _stateSubscription = _razorpayService.paymentStateStream.listen((newState) {
      state = newState;
    });

    ref.onDispose(() {
      _stateSubscription?.cancel();
      _stateSubscription = null;
    });

    return PaymentState.idle;
  }

  Future<bool> initiatePayment({
    required PaymentRequest paymentRequest,
    required String tenantId,
    required String propertyId,
  }) async {
    return _razorpayService.initiatePayment(
      paymentRequest: paymentRequest,
      tenantId: tenantId,
      propertyId: propertyId,
    );
  }

  void reset() => _razorpayService.reset();
}

/// Riverpod state notifier for payment state
final paymentStateNotifierProvider =
    NotifierProvider<PaymentNotifier, PaymentState>(PaymentNotifier.new);

/// Riverpod stream provider for payment responses
final paymentResponseStreamProvider = StreamProvider<PaymentResponse>((ref) {
  final razorpayService = ref.watch(razorpayServiceProvider);
  return razorpayService.paymentResponseStream;
});
