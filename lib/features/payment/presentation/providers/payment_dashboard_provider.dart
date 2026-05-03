import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:rentdone/features/payment/data/gateways/payment_gateway.dart';
import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_di.dart';
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
  final _firestore = FirebaseFirestore.instance;

  Future<PaymentDue?> _getTenantDue(String uid) async {
    final doc = await _firestore.collection('tenants').doc(uid).get();

    if (!doc.exists) return null;

    final data = doc.data()!;

    final rent = (data['rentAmount'] ?? 0) as int;

    return PaymentDue(
      leaseId: uid,
      paymentId: '',
      tenantId: uid,
      ownerId: data['ownerId'] ?? '',
      propertyId: data['propertyId'] ?? '',
      propertyName: data['propertyName'] ?? '',
      ownerName: data['ownerName'] ?? '',
      monthlyRent: rent,
      dueDate: DateTime.now(),
      lateFeeAmount: 0,
      totalPayable: rent,
      daysRemaining: 5,
      paymentStatus: 'pending',
      lastTransactionStatus: null,
      receiptUrl: null,
    );
  }

  @override
  Future<PaymentDashboardState> build() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const UnauthorizedFailure();
    }

    final due = await _getTenantDue(user.uid);

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
      final due = await _getTenantDue(user.uid);

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
    var due = current.due;

    if (due == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        due = await _getTenantDue(user.uid);
      }
    }

    if (due == null) {
      const msg = 'Tenant data not found. Cannot proceed with payment.';
      state = AsyncValue.data(
        current.copyWith(
          flowStatus: PaymentFlowStatus.failure,
          message: msg,
        ),
      );
      return null;
    }

    final appConfig = await AppConfigService().getConfig(forceRefresh: true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    // ✅ FETCH CORRECT EMAIL + PHONE FROM FIRESTORE
    final tenantDoc =
        await _firestore.collection('tenants').doc(uid).get();

    final tenantData = tenantDoc.data() ?? {};

    final email = (tenantData['email'] ?? '').toString().trim();

    final phone = (
      tenantData['phone'] ??
      tenantData['phoneNumber'] ??
      ''
    ).toString().trim();

    if (email.isEmpty || phone.isEmpty) {
      throw Exception("Tenant contact details missing.");
    }

    if (!appConfig.paymentsEnabled || appConfig.maintenanceMode) {
      const msg = 'Payments are currently disabled.';
      state = AsyncValue.data(
        current.copyWith(
          flowStatus: PaymentFlowStatus.failure,
          message: msg,
        ),
      );
      return null;
    }

    state = AsyncValue.data(
      current.copyWith(
        flowStatus: PaymentFlowStatus.processingPayment,
        clearMessage: true,
      ),
    );

    try {
      final intent = await ref
          .read(createPaymentIntentUseCaseProvider)
          .call(
            leaseId: uid,
            month: DateTime.now().month,
            year: DateTime.now().year,
            gateway: gateway,
           idempotencyKey: '${uid}_${DateTime.now().year}_${DateTime.now().month}_$gateway',
          );

      final result = await paymentGateway.initializePayment(
        PaymentGatewayRequest(
          orderId: intent.orderId ?? '',
          gatewayKey: intent.keyId ?? '',
          amount: intent.amount,
          currency: intent.currency,
          paymentId: intent.paymentId,

          // ✅ FINAL FIX HERE
          tenantEmail: email,
          tenantPhone: phone,
        ),
      );

      if (!result.isSuccess) {
        throw Exception(result.failureReason ?? 'Payment failed');
      }

      await ref.read(verifyPaymentUseCaseProvider).call(
        paymentId: intent.paymentId,
        gateway: gateway,
        payload: {
          'orderId': result.orderId,
          'paymentId': result.gatewayPaymentId,
          'signature': result.signature,
        },
      );

      final updatedDue = await _getTenantDue(uid);

      state = AsyncValue.data(
        current.copyWith(
          due: updatedDue,
          flowStatus: PaymentFlowStatus.success,
          message: 'Payment successful',
        ),
      );

      return intent;
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(
          flowStatus: PaymentFlowStatus.failure,
          message: e.toString(),
        ),
      );
      return null;
    }
  }
}

final paymentDashboardProvider =
    AsyncNotifierProvider<PaymentDashboardNotifier, PaymentDashboardState>(
      PaymentDashboardNotifier.new,
    );