import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

/// Subscription plan configuration
class SubscriptionPlanConfig {
  final String code;
  final String externalPlanId;
  final String title;
  final int monthlyPrice; // in INR
  final int tenantLimit;
  final String description;

  const SubscriptionPlanConfig({
    required this.code,
    required this.externalPlanId,
    required this.title,
    required this.monthlyPrice,
    required this.tenantLimit,
    required this.description,
  });
}

const freePlanConfig = SubscriptionPlanConfig(
  code: 'free',
  externalPlanId: '',
  title: 'Free',
  monthlyPrice: 0,
  tenantLimit: 2,
  description: 'Starter plan allowing owners to add up to 2 tenants for free.',
);

const basicPlanConfig = SubscriptionPlanConfig(
  code: 'basic',
  externalPlanId: 'basic_monthly_10tenants',
  title: 'Basic',
  monthlyPrice: 99,
  tenantLimit: 10,
  description: 'Basic plan allowing up to 10 tenants with monthly billing.',
);

const proPlanConfig = SubscriptionPlanConfig(
  code: 'pro',
  externalPlanId: 'pro_monthly_50tenants',
  title: 'Pro',
  monthlyPrice: 499,
  tenantLimit: 50,
  description:
      'Professional plan allowing up to 50 tenants with monthly billing.',
);

const subscriptionPlans = <SubscriptionPlanConfig>[
  freePlanConfig,
  basicPlanConfig,
  proPlanConfig,
];

SubscriptionPlanConfig planConfigByCode(String code) {
  return subscriptionPlans.firstWhere(
    (p) => p.code == code,
    orElse: () => freePlanConfig,
  );
}

/// Owner subscription data model
class OwnerSubscriptionData {
  final String ownerId;
  final String email;
  final String subscriptionPlan;
  final String paymentStatus; // active, failed, pending, expired
  final int tenantLimit;
  final int currentTenantCount;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionExpiry;
  final String? paymentOrderId;
  final String? paymentSubscriptionId;

  const OwnerSubscriptionData({
    required this.ownerId,
    required this.email,
    required this.subscriptionPlan,
    required this.paymentStatus,
    required this.tenantLimit,
    required this.currentTenantCount,
    required this.subscriptionStartDate,
    required this.subscriptionExpiry,
    this.paymentOrderId,
    this.paymentSubscriptionId,
  });

  SubscriptionPlanConfig get planConfig => planConfigByCode(subscriptionPlan);

  double get usageRatio {
    if (tenantLimit <= 0) return 0;
    final ratio = currentTenantCount / tenantLimit;
    return ratio.clamp(0, 1).toDouble();
  }

  bool get isActive => paymentStatus == 'active' && subscriptionExpiry != null
      ? subscriptionExpiry!.isAfter(DateTime.now())
      : paymentStatus == 'active';

  factory OwnerSubscriptionData.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    return OwnerSubscriptionData(
      ownerId: (map['ownerId'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      subscriptionPlan: ((map['subscriptionPlan'] as String?) ?? 'free')
          .toLowerCase(),
      paymentStatus: ((map['paymentStatus'] as String?) ?? 'active')
          .toLowerCase(),
      tenantLimit: (map['tenantLimit'] as num?)?.toInt() ?? 2,
      currentTenantCount: (map['currentTenantCount'] as num?)?.toInt() ?? 0,
      subscriptionStartDate: parseDate(map['subscriptionStartDate']),
      subscriptionExpiry: parseDate(map['subscriptionExpiry']),
      paymentOrderId:
          (map['paymentOrderId'] as String?) ??
          (map['cashfreeOrderId'] as String?),
      paymentSubscriptionId:
          (map['paymentSubscriptionId'] as String?) ??
          (map['cashfreeSubscriptionId'] as String?),
    );
  }
}

/// Payment intent for initiating owner subscription payment
class OwnerSubscriptionPaymentIntent {
  final String paymentId;
  final String orderId;
  final String keyId;
  final int amountInPaise;
  final String currency;
  final String planCode;
  final int tenantLimit;

  const OwnerSubscriptionPaymentIntent({
    required this.paymentId,
    required this.orderId,
    required this.keyId,
    required this.amountInPaise,
    required this.currency,
    required this.planCode,
    required this.tenantLimit,
  });

  factory OwnerSubscriptionPaymentIntent.fromMap(Map<String, dynamic> map) {
    return OwnerSubscriptionPaymentIntent(
      paymentId:
          (map['paymentId'] as String?) ??
          (map['subscriptionPaymentId'] as String?) ??
          '',
      orderId: (map['orderId'] as String?) ?? '',
      keyId: (map['keyId'] as String?) ?? '',
      amountInPaise: (map['amountInPaise'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String?) ?? 'INR',
      planCode: (map['planCode'] as String?) ?? 'free',
      tenantLimit: (map['tenantLimit'] as num?)?.toInt() ?? 2,
    );
  }
}

/// Service for managing owner subscriptions
class OwnerSubscriptionService {
  OwnerSubscriptionService();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  /// Ensure owner subscription profile exists
  Future<void> ensureOwnerSubscriptionDoc({
    required String ownerId,
    required String email,
  }) async {
    final callable = _functions.httpsCallable('ensureOwnerSubscriptionProfile');
    await callable.call(<String, dynamic>{'ownerId': ownerId, 'email': email});
  }

  /// Get owner subscription data
  Future<OwnerSubscriptionData> getOwnerSubscription({
    required String ownerId,
    required String email,
  }) async {
    final callable = _functions.httpsCallable('getOwnerSubscriptionSnapshot');
    final result = await callable.call(<String, dynamic>{
      'ownerId': ownerId,
      'email': email,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return OwnerSubscriptionData.fromMap(data);
  }

  /// Activate free plan for owner
  Future<void> activateFreePlan({required String ownerId}) async {
    final callable = _functions.httpsCallable('activateOwnerFreeSubscription');
    await callable.call(<String, dynamic>{'ownerId': ownerId});
  }

  /// Create payment intent for subscription
  Future<OwnerSubscriptionPaymentIntent> createSubscriptionPaymentIntent({
    required SubscriptionPlanConfig plan,
  }) async {
    if (plan.code == 'free') {
      throw ArgumentError('Free plan does not require payment intent');
    }

    final callable = _functions.httpsCallable(
      'createOwnerSubscriptionPaymentIntent',
    );
    final result = await callable.call(<String, dynamic>{
      'planCode': plan.code,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return OwnerSubscriptionPaymentIntent.fromMap(data);
  }

  /// Verify subscription payment
  Future<void> verifySubscriptionPayment({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final callable = _functions.httpsCallable('verifyOwnerSubscriptionPayment');
    await callable.call(<String, dynamic>{
      'subscriptionPaymentId': paymentId,
      'paymentId': paymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
      'payload': {
        'orderId': razorpayOrderId,
        'paymentId': razorpayPaymentId,
        'signature': razorpaySignature,
      },
    });
  }

  /// Get active tenant count
  Future<int> getActiveTenantCountFromSnapshot({
    required String ownerId,
    required String email,
  }) async {
    final sub = await getOwnerSubscription(ownerId: ownerId, email: email);
    return sub.currentTenantCount;
  }
}

/// Provider for subscription service
final ownerSubscriptionServiceProvider = Provider<OwnerSubscriptionService>((
  ref,
) {
  return OwnerSubscriptionService();
});

/// Provider for owner subscription data
final subscriptionProvider = FutureProvider<OwnerSubscriptionData>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final ownerId = auth.currentUser?.uid;
  if (ownerId == null || ownerId.isEmpty) {
    return const OwnerSubscriptionData(
      ownerId: '',
      email: '',
      subscriptionPlan: 'free',
      paymentStatus: 'active',
      tenantLimit: 2,
      currentTenantCount: 0,
      subscriptionStartDate: null,
      subscriptionExpiry: null,
    );
  }

  final email = auth.currentUser?.email ?? '';
  final service = ref.watch(ownerSubscriptionServiceProvider);
  return service.getOwnerSubscription(ownerId: ownerId, email: email);
});

/// Provider for active tenant count
final tenantListProvider = FutureProvider<int>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final ownerId = auth.currentUser?.uid;
  if (ownerId == null || ownerId.isEmpty) {
    return 0;
  }

  final email = auth.currentUser?.email ?? '';
  final service = ref.watch(ownerSubscriptionServiceProvider);
  return service.getActiveTenantCountFromSnapshot(
    ownerId: ownerId,
    email: email,
  );
});

/// Provider for tenant limit
final tenantLimitProvider = Provider<int>((ref) {
  final sub = ref.watch(subscriptionProvider);
  return sub.maybeWhen(data: (data) => data.tenantLimit, orElse: () => 2);
});
