import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/payment/data/gateways/payment_gateway.dart';
import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_di.dart';
import 'package:rentdone/core/logging/payment_event_logger.dart';
import 'package:rentdone/core/config/app_config_service.dart';

enum PaymentFlowStatus { idle, loading, processingPayment, success, failure }

class PaymentDashboardState {
  final PaymentFlowStatus flowStatus;
  final PaymentDue? due;
  final String? message;

  const PaymentDashboardState({
    required this.flowStatus,
    this.due,
    this.message,
  });

  PaymentDashboardState copyWith({
    PaymentFlowStatus? flowStatus,
    PaymentDue? due,
    String? message,
    bool clearMessage = false,
  }) {
    return PaymentDashboardState(
      flowStatus: flowStatus ?? this.flowStatus,
      due: due ?? this.due,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  factory PaymentDashboardState.initial() {
    return const PaymentDashboardState(flowStatus: PaymentFlowStatus.idle);
  }
}

class PaymentDashboardNotifier extends AsyncNotifier<PaymentDashboardState> {
  @override
  Future<PaymentDashboardState> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const UnauthorizedFailure();
    }

    final due = await ref
        .read(getCurrentDueUseCaseProvider)
        .call(tenantId: user.uid);

    return PaymentDashboardState.initial().copyWith(
      due: due,
      flowStatus: PaymentFlowStatus.idle,
    );
  }

  Future<void> refreshDue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = AsyncValue.error(const UnauthorizedFailure(), StackTrace.current);
      return;
    }

    state = await AsyncValue.guard(() async {
      final due = await ref
          .read(getCurrentDueUseCaseProvider)
          .call(tenantId: user.uid);
      return (state.value ?? PaymentDashboardState.initial()).copyWith(
        due: due,
        flowStatus: PaymentFlowStatus.idle,
        clearMessage: true,
      );
    });
  }

  Future<PaymentIntent?> createAndPay({
    required String gateway,
    required PaymentGateway paymentGateway,
    required String tenantEmail,
    required String tenantPhone,
  }) async {
    final current = state.value ?? PaymentDashboardState.initial();
    final due = current.due;
    if (due == null) return null;

    final logger = PaymentEventLogger.instance;
    // Always revalidate payment toggles at charge time to avoid stale cache
    // blocking valid payments after backend config updates.
    final appConfig = await AppConfigService().getConfig(forceRefresh: true);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final idempotencyKey =
        'tenant_${FirebaseAuth.instance.currentUser!.uid}_${due.leaseId}_${due.dueDate.year}_${due.dueDate.month}_${gateway.toLowerCase()}';
    final payableAmount = due.totalPayable > 0
        ? due.totalPayable
        : (due.monthlyRent + due.lateFeeAmount);

    if (!appConfig.paymentsEnabled || appConfig.maintenanceMode) {
      final blockCode = appConfig.maintenanceMode
          ? 'maintenance-mode'
          : 'payments-disabled';
      final blockMessage = appConfig.maintenanceMode
          ? 'Payments are temporarily paused for maintenance.'
          : 'Payments are currently disabled by admin settings.';
      await logger.logError(
        event: 'PAYMENT_FAILURE',
        userId: userId,
        tenantId: due.tenantId,
        ownerId: due.ownerId,
        paymentId: due.paymentId,
        idempotencyKey: idempotencyKey,
        amount: payableAmount,
        method: gateway,
        status: 'blocked',
        errorCode: blockCode,
        errorMessage: blockMessage,
      );
      state = AsyncValue.data(
        current.copyWith(
          flowStatus: PaymentFlowStatus.failure,
          message: blockMessage,
        ),
      );
      return null;
    }

    if (gateway == 'razorpay' && !appConfig.razorpayEnabled) {
      const blockMessage = 'Razorpay is currently disabled by admin settings.';
      await logger.logError(
        event: 'PAYMENT_FAILURE',
        userId: userId,
        tenantId: due.tenantId,
        ownerId: due.ownerId,
        paymentId: due.paymentId,
        idempotencyKey: idempotencyKey,
        amount: payableAmount,
        method: gateway,
        status: 'blocked',
        errorCode: 'razorpay-disabled',
        errorMessage: blockMessage,
      );
      state = AsyncValue.data(
        current.copyWith(
          flowStatus: PaymentFlowStatus.failure,
          message: blockMessage,
        ),
      );
      return null;
    }

    if (current.flowStatus == PaymentFlowStatus.failure) {
      await logger.logEvent(
        event: 'PAYMENT_RETRY',
        userId: userId,
        tenantId: due.tenantId,
        ownerId: due.ownerId,
        paymentId: due.paymentId,
        idempotencyKey: idempotencyKey,
        amount: payableAmount,
        method: gateway,
        status: 'retry',
      );
    }

    await logger.logEvent(
      event: 'PAYMENT_START',
      userId: userId,
      tenantId: due.tenantId,
      ownerId: due.ownerId,
      paymentId: due.paymentId,
      idempotencyKey: idempotencyKey,
      amount: payableAmount,
      method: gateway,
      status: 'initiated',
    );

    state = AsyncValue.data(
      current.copyWith(
        flowStatus: PaymentFlowStatus.processingPayment,
        clearMessage: true,
      ),
    );

    PaymentIntent? createdIntent;

    final result = await AsyncValue.guard(() async {
      final intent = await ref.read(createPaymentIntentUseCaseProvider).call(
        leaseId: due.leaseId,
        month: due.dueDate.month,
        year: due.dueDate.year,
        gateway: gateway,
        idempotencyKey: idempotencyKey,
      );
      createdIntent = intent;

      if (gateway == 'razorpay' &&
          (intent.orderId == null || intent.keyId == null)) {
        throw const ServerFailure('Payment gateway not configured');
      }

      if (gateway == 'cashfree' &&
          (intent.paymentSessionId == null ||
              intent.keyId == null ||
              intent.orderId == null)) {
        throw const ServerFailure('Cashfree payment session not available');
      }

      final gatewayPayableAmount = gateway == 'razorpay'
          ? (intent.totalPayableInPaise > 0
            ? intent.totalPayableInPaise
            : intent.amount)
          : intent.amount;

      final gatewayResult = await paymentGateway.initializePayment(
        PaymentGatewayRequest(
          orderId: intent.orderId ?? '',
          gatewayKey: intent.keyId ?? '',
          amount: gatewayPayableAmount,
          currency: intent.currency,
          paymentId: intent.paymentId,
          tenantEmail: tenantEmail,
          tenantPhone: tenantPhone,
          paymentSessionId: intent.paymentSessionId,
        ),
      );

      if (!gatewayResult.isSuccess) {
        throw ServerFailure(gatewayResult.failureReason ?? 'Payment failed');
      }

      await ref
          .read(verifyPaymentUseCaseProvider)
          .call(
            paymentId: intent.paymentId,
            gateway: gateway,
            payload: {
              'orderId': gatewayResult.orderId,
              'paymentId': gatewayResult.gatewayPaymentId,
              'signature': gatewayResult.signature,
            },
          );

      final updatedDue = await ref
          .read(getCurrentDueUseCaseProvider)
          .call(tenantId: FirebaseAuth.instance.currentUser!.uid);

      final successState = current.copyWith(
        due: updatedDue,
        flowStatus: PaymentFlowStatus.success,
        message: 'Payment verified',
      );

      await logger.logEvent(
        event: 'PAYMENT_SUCCESS',
        userId: userId,
        tenantId: due.tenantId,
        ownerId: due.ownerId,
        paymentId: intent.paymentId,
        idempotencyKey: intent.idempotencyKey,
        amount: payableAmount,
        method: gateway,
        status: 'paid',
      );

      state = AsyncValue.data(successState);
      return intent;
    });

    if (result.hasError) {
      final failure = result.error;
      final message = failure is PaymentFailure
        ? failure.message
        : (() {
          final raw = failure
              ?.toString()
              .replaceFirst('Exception: ', '')
              .trim() ??
            '';
          return raw.isEmpty ? 'Payment failed. Please try again.' : raw;
        })();
      final errorCode = failure is PaymentFailure ? failure.code : 'unknown';
      await logger.logError(
        event: 'PAYMENT_FAILURE',
        userId: userId,
        tenantId: due.tenantId,
        ownerId: due.ownerId,
        paymentId: createdIntent?.paymentId ?? due.paymentId,
        idempotencyKey: createdIntent?.idempotencyKey ?? idempotencyKey,
        amount: payableAmount,
        method: gateway,
        status: 'failed',
        errorCode: errorCode,
        errorMessage: message,
        error: failure,
        stackTrace: StackTrace.current,
      );
      state = AsyncValue.data(
        current.copyWith(
          flowStatus: PaymentFlowStatus.failure,
          message: message,
        ),
      );
      return null;
    }

    return result.value;
  }
}

final paymentDashboardProvider =
    AsyncNotifierProvider<PaymentDashboardNotifier, PaymentDashboardState>(
      PaymentDashboardNotifier.new,
    );
