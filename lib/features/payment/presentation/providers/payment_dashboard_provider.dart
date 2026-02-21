import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/payment/data/gateways/payment_gateway.dart';
import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_di.dart';
import 'package:uuid/uuid.dart';

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
  }) {
    return PaymentDashboardState(
      flowStatus: flowStatus ?? this.flowStatus,
      due: due ?? this.due,
      message: message ?? this.message,
    );
  }

  factory PaymentDashboardState.initial() {
    return const PaymentDashboardState(flowStatus: PaymentFlowStatus.idle);
  }
}

class PaymentDashboardNotifier extends AsyncNotifier<PaymentDashboardState> {
  final _uuid = const Uuid();

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

    state = AsyncValue.data(
      current.copyWith(
        flowStatus: PaymentFlowStatus.processingPayment,
        message: null,
      ),
    );

    final result = await AsyncValue.guard(() async {
      final intent = await ref
          .read(createPaymentIntentUseCaseProvider)
          .call(
            leaseId: due.leaseId,
            month: due.dueDate.month,
            year: due.dueDate.year,
            gateway: gateway,
            idempotencyKey: _uuid.v4(),
          );

      if (gateway == 'razorpay' &&
          (intent.orderId == null || intent.keyId == null)) {
        throw const ServerFailure('Payment gateway not configured');
      }

      final gatewayResult = await paymentGateway.initializePayment(
        PaymentGatewayRequest(
          orderId: intent.orderId ?? '',
          gatewayKey: intent.keyId ?? '',
          amount: intent.amount,
          currency: intent.currency,
          paymentId: intent.paymentId,
          tenantEmail: tenantEmail,
          tenantPhone: tenantPhone,
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

      state = AsyncValue.data(successState);
      return intent;
    });

    if (result.hasError) {
      final failure = result.error;
      final message = failure is PaymentFailure
          ? failure.message
          : 'Payment failed';
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
