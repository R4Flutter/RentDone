import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:rentdone/features/tenant/payment_module/models/payment_enums.dart';
import 'package:rentdone/features/tenant/payment_module/models/payment_record_model.dart';
import 'package:rentdone/features/tenant/payment_module/models/payment_summary_model.dart';
import 'package:rentdone/features/tenant/payment_module/models/tenant_model.dart';
import 'package:rentdone/features/tenant/payment_module/services/payment_constants.dart';

class PaymentService {
  PaymentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  DateTime get _monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _nextMonthStart {
    final start = _monthStart;
    return DateTime(start.year, start.month + 1, 1);
  }

  Stream<TenantModel?> watchTenant(String tenantId) {
    return _firestore
        .collection(PaymentConstants.tenantsCollection)
        .where('tenantId', isEqualTo: tenantId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          final doc = snapshot.docs.first;
          return TenantModel.fromMap(documentId: doc.id, map: doc.data());
        });
  }

  Future<TenantModel?> fetchTenant(String tenantId) async {
    final snapshot = await _firestore
        .collection(PaymentConstants.tenantsCollection)
        .where('tenantId', isEqualTo: tenantId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    return TenantModel.fromMap(documentId: doc.id, map: doc.data());
  }

  Stream<List<PaymentRecordModel>> watchSuccessfulPaymentsForCurrentMonth(
    String tenantId,
  ) {
    return _firestore
        .collection(PaymentConstants.paymentsCollection)
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: PaymentConstants.statusSuccess)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_monthStart),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(_nextMonthStart))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentRecordModel.fromMap(doc.data()))
              .toList(growable: false),
        );
  }

  Future<double> calculateDue(String tenantId) async {
    final tenant = await fetchTenant(tenantId);
    if (tenant == null) {
      return 0;
    }

    final monthlyPaid = await _sumSuccessfulPaymentsForCurrentMonth(tenantId);
    final due = tenant.rent - monthlyPaid;
    return due <= 0 ? 0.0 : due;
  }

  Stream<PaymentSummaryModel> watchCurrentMonthSummary(String tenantId) {
    final controller = StreamController<PaymentSummaryModel>();

    TenantModel? tenant;
    List<PaymentRecordModel> payments = const [];
    StreamSubscription<TenantModel?>? tenantSub;
    StreamSubscription<List<PaymentRecordModel>>? paymentSub;

    void emit() {
      if (controller.isClosed) {
        return;
      }

      final rent = tenant?.rent ?? 0;
      final paid = payments.fold<double>(
        0,
        (total, payment) => total + payment.amount,
      );
      final double due = (rent - paid) <= 0 ? 0.0 : (rent - paid);

      controller.add(
        PaymentSummaryModel(
          tenant: tenant,
          currentMonthSuccessfulPayments: payments,
          totalPaidThisMonth: paid,
          dueAmount: due,
        ),
      );
    }

    controller.onListen = () {
      // Emit safe fallback immediately so UI never stalls at a loading state.
      emit();

      tenantSub = watchTenant(tenantId).listen((value) {
        tenant = value;
        emit();
      }, onError: controller.addError);

      paymentSub = watchSuccessfulPaymentsForCurrentMonth(tenantId).listen((
        value,
      ) {
        payments = value;
        emit();
      }, onError: controller.addError);
    };

    controller.onCancel = () async {
      await tenantSub?.cancel();
      await paymentSub?.cancel();
    };

    return controller.stream;
  }

  Future<String> markPaidViaCashPending({
    required String tenantId,
    required double amount,
  }) async {
    throw UnsupportedError(
      'Legacy local payment writes are disabled. Use callable-backed payment intents.',
    );
  }

  Future<String> createRazorpayPendingPayment({
    required String tenantId,
    required double rentAmount,
    required double totalAmount,
  }) async {
    throw UnsupportedError(
      'Legacy local payment writes are disabled. Use callable-backed payment intents.',
    );
  }

  Future<void> confirmOwnerCashPayment({
    required String paymentId,
    required String ownerId,
  }) async {
    throw UnsupportedError(
      'Legacy local payment writes are disabled. Use callable-backed payment intents.',
    );
  }

  Future<void> recordRazorpaySuccessPayment({
    required String paymentId,
    required String tenantId,
    required double rentAmount,
    required double totalAmount,
    required String razorpayOrderId,
    required String razorpayPaymentId,
  }) async {
    throw UnsupportedError(
      'Legacy local payment writes are disabled. Use callable-backed payment intents.',
    );
  }

  Future<void> recordRazorpayFailedPayment({
    required String paymentId,
    required String tenantId,
    required double amount,
    String? errorMessage,
  }) async {
    throw UnsupportedError(
      'Legacy local payment writes are disabled. Use callable-backed payment intents.',
    );
  }

  Future<double> _sumSuccessfulPaymentsForCurrentMonth(String tenantId) async {
    final snapshot = await _firestore
        .collection(PaymentConstants.paymentsCollection)
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: PaymentConstants.statusSuccess)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_monthStart),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(_nextMonthStart))
        .get();

    return snapshot.docs.fold<double>(0, (total, doc) {
      final data = doc.data();
      return total + ((data['amount'] as num?)?.toDouble() ?? 0);
    });
  }
}
