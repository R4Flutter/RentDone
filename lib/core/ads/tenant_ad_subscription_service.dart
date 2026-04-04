import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TenantAdPlan {
  final String code;
  final String title;
  final int priceInr;
  final int durationDays;

  const TenantAdPlan({
    required this.code,
    required this.title,
    required this.priceInr,
    required this.durationDays,
  });
}

const tenantAdMonthlyPlan = TenantAdPlan(
  code: 'ad_free_1m',
  title: 'Ad Free - 1 Month',
  priceInr: 29,
  durationDays: 30,
);

const tenantAdBiMonthlyPlan = TenantAdPlan(
  code: 'ad_free_2m',
  title: 'Ad Free - 2 Months',
  priceInr: 49,
  durationDays: 60,
);

const tenantAdPlans = <TenantAdPlan>[
  tenantAdMonthlyPlan,
  tenantAdBiMonthlyPlan,
];

class TenantAdSubscriptionState {
  final String planCode;
  final DateTime? startDate;
  final DateTime? expiryDate;

  const TenantAdSubscriptionState({
    required this.planCode,
    required this.startDate,
    required this.expiryDate,
  });

  bool get isActive {
    final expiry = expiryDate;
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  int get remainingDays {
    final expiry = expiryDate;
    if (expiry == null) return 0;
    final diff = expiry.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  static const empty = TenantAdSubscriptionState(
    planCode: 'none',
    startDate: null,
    expiryDate: null,
  );
}

class TenantAdSubscriptionPaymentIntent {
  final String subscriptionPaymentId;
  final String orderId;
  final String keyId;
  final int amountInPaise;
  final String currency;
  final String planCode;
  final String planTitle;
  final int durationDays;
  final String idempotencyKey;

  const TenantAdSubscriptionPaymentIntent({
    required this.subscriptionPaymentId,
    required this.orderId,
    required this.keyId,
    required this.amountInPaise,
    required this.currency,
    required this.planCode,
    required this.planTitle,
    required this.durationDays,
    required this.idempotencyKey,
  });
}

class TenantAdSubscriptionService {
  TenantAdSubscriptionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<TenantAdSubscriptionState> getCurrent() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return TenantAdSubscriptionState.empty;
    }

    final tenantDoc = await _firestore.collection('tenants').doc(uid).get();
    final tenantData = tenantDoc.data() ?? <String, dynamic>{};
    final subRaw = tenantData['adSubscription'];
    if (subRaw is! Map) {
      return TenantAdSubscriptionState.empty;
    }

    final sub = Map<String, dynamic>.from(subRaw);
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return null;
    }

    return TenantAdSubscriptionState(
      planCode: (sub['planCode'] as String? ?? 'none').toLowerCase(),
      startDate: parseDate(sub['startDate']),
      expiryDate: parseDate(sub['expiryDate']),
    );
  }

  Future<bool> isAdFreeActive() async {
    final state = await getCurrent();
    return state.isActive;
  }

  Future<TenantAdSubscriptionPaymentIntent> createPaymentIntent(
    TenantAdPlan plan,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not logged in');
    }

    final callable = _functions.httpsCallable(
      'createTenantSubscriptionPaymentIntent',
    );
    final idempotencyKey =
        'tenant_sub_${uid}_${plan.code}_${DateTime.now().millisecondsSinceEpoch}';

    final response = await callable.call({
      'planCode': plan.code,
      'idempotencyKey': idempotencyKey,
    });
    final data = Map<String, dynamic>.from(response.data as Map);

    final subscriptionPaymentId = (data['subscriptionPaymentId'] ?? '')
        .toString()
        .trim();
    final orderId = (data['orderId'] ?? '').toString().trim();
    final keyId = (data['keyId'] ?? '').toString().trim();

    if (subscriptionPaymentId.isEmpty || orderId.isEmpty || keyId.isEmpty) {
      throw Exception('Subscription payment intent initialization failed.');
    }

    return TenantAdSubscriptionPaymentIntent(
      subscriptionPaymentId: subscriptionPaymentId,
      orderId: orderId,
      keyId: keyId,
      amountInPaise:
          (data['amountInPaise'] as num?)?.toInt() ?? (plan.priceInr * 100),
      currency: (data['currency'] ?? 'INR').toString().trim(),
      planCode: (data['planCode'] ?? plan.code).toString().trim(),
      planTitle: (data['planTitle'] ?? plan.title).toString().trim(),
      durationDays:
          (data['durationDays'] as num?)?.toInt() ?? plan.durationDays,
      idempotencyKey: (data['idempotencyKey'] ?? idempotencyKey)
          .toString()
          .trim(),
    );
  }

  Future<void> verifySubscriptionPayment({
    required String subscriptionPaymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not logged in');
    }

    final callable = _functions.httpsCallable(
      'verifyTenantSubscriptionPayment',
    );
    await callable.call({
      'subscriptionPaymentId': subscriptionPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
  }
}
