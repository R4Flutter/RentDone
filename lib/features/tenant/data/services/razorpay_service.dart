import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:rentdone/features/tenant/data/services/payment_constants.dart';
import 'package:rentdone/features/tenant/data/services/payment_service.dart';

class RazorpayOrderData {
  const RazorpayOrderData({
    required this.orderId,
    required this.paymentId,
    required this.tenantId,
    required this.rentAmountInRupees,
    required this.totalAmountInRupees,
    required this.keyId,
    required this.amountInPaise,
    required this.currency,
  });

  final String orderId;
  final String paymentId;
  final String tenantId;
  final double rentAmountInRupees;
  final double totalAmountInRupees;
  final String keyId;
  final int amountInPaise;
  final String currency;
}

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class RazorpayService {
  RazorpayService({
    required PaymentService paymentService,
    FirebaseFunctions? functions,
  }) : _paymentService = paymentService,
       _functions = functions ?? FirebaseFunctions.instance {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  final PaymentService _paymentService;
  final FirebaseFunctions _functions;

  late final Razorpay _razorpay;

  Completer<RazorpayCheckoutResult>? _completer;
  RazorpayOrderData? _activeOrder;

  Future<RazorpayCheckoutResult> startTenantPayment({
    required String tenantId,
    required double rentAmountInRupees,
    required double totalAmountInRupees,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
  }) async {
    if (rentAmountInRupees <= 0 || totalAmountInRupees <= 0) {
      return const RazorpayCheckoutResult(
        success: false,
        message: 'Amount must be greater than zero.',
      );
    }

    try {
      final paymentId = await _paymentService.createRazorpayPendingPayment(
        tenantId: tenantId,
        rentAmount: rentAmountInRupees,
        totalAmount: totalAmountInRupees,
      );

      final order = await _createOrder(
        tenantId: tenantId,
        rentAmountInRupees: rentAmountInRupees,
        totalAmountInRupees: totalAmountInRupees,
        paymentId: paymentId,
      );

      _activeOrder = order;
      _completer = Completer<RazorpayCheckoutResult>();

      final options = {
        'key': order.keyId,
        'order_id': order.orderId,
        'amount': order.amountInPaise,
        'currency': order.currency,
        'name': 'RentDone',
        'description': 'Monthly rent payment',
        'prefill': {
          'name': tenantName,
          'email': tenantEmail,
          'contact': tenantPhone,
        },
        'notes': {'tenantId': tenantId, 'paymentId': order.paymentId},
      };

      _razorpay.open(options);

      return await _completer!.future.timeout(
        PaymentConstants.checkoutTimeout,
        onTimeout: () async {
          await _recordFailure(
            tenantId: order.tenantId,
            paymentId: order.paymentId,
            rentAmountInRupees: order.rentAmountInRupees,
            message: 'Checkout timeout. Please try again.',
          );
          return const RazorpayCheckoutResult(
            success: false,
            message: 'Checkout timeout. Please try again.',
          );
        },
      );
    } catch (error, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Razorpay startTenantPayment failed',
      );
      return RazorpayCheckoutResult(
        success: false,
        message: _friendlyError(error),
      );
    }
  }

  Future<RazorpayOrderData> _createOrder({
    required String tenantId,
    required double rentAmountInRupees,
    required double totalAmountInRupees,
    required String paymentId,
  }) async {
    final amountInPaise = (totalAmountInRupees * 100).round();

    final callable = _functions.httpsCallable(
      PaymentConstants.createRazorpayOrderCallable,
    );

    final response = await callable.call({
      'paymentId': paymentId,
      'amount': amountInPaise,
      'currency': 'INR',
      'receipt': paymentId,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    final orderId = (data['orderId'] ?? data['id'] ?? '').toString().trim();

    final keyId =
        (data['keyId'] ??
                const String.fromEnvironment('RAZORPAY_KEY', defaultValue: ''))
            .toString()
            .trim();

    if (orderId.isEmpty || keyId.isEmpty) {
      throw StateError('Razorpay order initialization failed.');
    }

    return RazorpayOrderData(
      orderId: orderId,
      paymentId: paymentId,
      tenantId: tenantId,
      rentAmountInRupees: rentAmountInRupees,
      totalAmountInRupees: totalAmountInRupees,
      keyId: keyId,
      amountInPaise: (data['amountInPaise'] as num?)?.toInt() ?? amountInPaise,
      currency: (data['currency'] ?? 'INR').toString().trim(),
    );
  }

  Future<bool> _verifySignatureBackendReady({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final callable = _functions.httpsCallable(
      PaymentConstants.confirmRazorpayPaymentCallable,
    );

    try {
      final response = await callable.call({
        'paymentId': paymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      return data['ok'] == true || data['verified'] == true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unimplemented' || e.code == 'not-found') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final order = _activeOrder;
    if (order == null) {
      _complete(
        const RazorpayCheckoutResult(
          success: false,
          message: 'Payment completed but order context is missing.',
        ),
      );
      return;
    }

    final rzpPaymentId = (response.paymentId ?? '').trim();
    final rzpOrderId = (response.orderId ?? order.orderId).trim();
    final signature = (response.signature ?? '').trim();

    if (rzpPaymentId.isEmpty || rzpOrderId.isEmpty || signature.isEmpty) {
      _complete(
        const RazorpayCheckoutResult(
          success: false,
          message: 'Payment response from gateway is incomplete.',
        ),
      );
      return;
    }

    try {
      final verified = await _verifySignatureBackendReady(
        paymentId: order.paymentId,
        razorpayOrderId: rzpOrderId,
        razorpayPaymentId: rzpPaymentId,
        razorpaySignature: signature,
      );

      if (!verified) {
        throw StateError('Payment verification failed.');
      }

      await _paymentService.recordRazorpaySuccessPayment(
        paymentId: order.paymentId,
        tenantId: order.tenantId,
        rentAmount: order.rentAmountInRupees,
        totalAmount: order.totalAmountInRupees,
        razorpayOrderId: rzpOrderId,
        razorpayPaymentId: rzpPaymentId,
      );

      _complete(const RazorpayCheckoutResult(success: true));
    } catch (error) {
      await _recordFailure(
        tenantId: order.tenantId,
        paymentId: order.paymentId,
        rentAmountInRupees: order.rentAmountInRupees,
        message: _friendlyError(error),
      );

      _complete(
        RazorpayCheckoutResult(success: false, message: _friendlyError(error)),
      );
    }
  }

  Future<void> _onPaymentError(PaymentFailureResponse response) async {
    final message = (response.message ?? 'Payment failed').trim();
    final order = _activeOrder;

    if (order != null) {
      await _recordFailure(
        tenantId: order.tenantId,
        paymentId: order.paymentId,
        rentAmountInRupees: order.rentAmountInRupees,
        message: message,
      );
    }

    _complete(RazorpayCheckoutResult(success: false, message: message));
  }

  Future<void> _onExternalWallet(ExternalWalletResponse response) async {
    final walletName = (response.walletName ?? 'wallet').trim();
    final message = 'External wallet selected: $walletName';

    final order = _activeOrder;

    if (order != null) {
      await _recordFailure(
        tenantId: order.tenantId,
        paymentId: order.paymentId,
        rentAmountInRupees: order.rentAmountInRupees,
        message: message,
      );
    }

    _complete(RazorpayCheckoutResult(success: false, message: message));
  }

  Future<void> _recordFailure({
    required String tenantId,
    required String paymentId,
    required double rentAmountInRupees,
    required String message,
  }) async {
    await _paymentService.recordRazorpayFailedPayment(
      paymentId: paymentId,
      tenantId: tenantId,
      amount: rentAmountInRupees,
      errorMessage: message,
    );
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException &&
        error.message != null &&
        error.message!.trim().isNotEmpty) {
      return error.message!.trim();
    }
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void _complete(RazorpayCheckoutResult result) {
    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
    _completer = null;
    _activeOrder = null;
  }

  void dispose() {
    _razorpay.clear();
    _completer = null;
    _activeOrder = null;
  }
}
