import 'package:rentdone/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_payment_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_property_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_tenant_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/dashboard_repository.dart';
import 'dart:async';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardFirebaseService _service;

  DashboardRepositoryImpl(this._service);

  @override
  Future<DashboardSummary> getDashboardSummary() {
    return _buildSummary();
  }

  @override
  Future<DashboardSummary> refreshDashboard() {
    return _buildSummary();
  }

  @override
  Stream<DashboardSummary> watchDashboardSummary() {
    final controller = StreamController<DashboardSummary>();

    List<DashboardPropertyDto> latestProperties = const [];
    List<DashboardPaymentDto> latestPayments = const [];
    int latestTenantCount = 0;
    bool hasProperties = false;
    bool hasPayments = false;
    bool hasTenants = false;

    void pushSummaryIfReady() {
      if (!hasProperties || !hasPayments || !hasTenants) return;

      controller.add(
        _toSummary(
          properties: latestProperties,
          payments: latestPayments,
          totalTenants: latestTenantCount,
        ),
      );
    }

    final propertiesSub = _service.watchProperties().listen((properties) {
      latestProperties = properties;
      hasProperties = true;
      pushSummaryIfReady();
    }, onError: controller.addError);

    final paymentsSub = _service.watchPayments().listen((payments) {
      latestPayments = payments;
      hasPayments = true;
      pushSummaryIfReady();
    }, onError: controller.addError);

    final tenantCountSub = _service.watchTenantCount().listen((tenantCount) {
      latestTenantCount = tenantCount;
      hasTenants = true;
      pushSummaryIfReady();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await propertiesSub.cancel();
      await paymentsSub.cancel();
      await tenantCountSub.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<List<AppMessage>> watchRecentMessages({int limit = 6}) {
    final controller = StreamController<List<AppMessage>>();

    List<AppMessage> latestMessages = const [];
    List<DashboardPaymentDto> latestPayments = const [];
    List<DashboardTenantDto> latestTenants = const [];
    bool hasMessages = false;
    bool hasPayments = false;
    bool hasTenants = false;

    void pushIfReady() {
      if (!hasMessages || !hasPayments || !hasTenants) return;
      controller.add(
        _buildUnifiedUpdates(
          messages: latestMessages,
          payments: latestPayments,
          tenants: latestTenants,
          limit: limit,
        ),
      );
    }

    final messagesSub = _service.watchRecentMessages(limit: 20).listen((items) {
      latestMessages = items.map((item) => item.toEntity()).toList();
      hasMessages = true;
      pushIfReady();
    }, onError: controller.addError);

    final paymentsSub = _service.watchPayments().listen((items) {
      latestPayments = items;
      hasPayments = true;
      pushIfReady();
    }, onError: controller.addError);

    final tenantsSub = _service.watchTenantActivity(limit: 20).listen((items) {
      latestTenants = items;
      hasTenants = true;
      pushIfReady();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await messagesSub.cancel();
      await paymentsSub.cancel();
      await tenantsSub.cancel();
    };

    return controller.stream;
  }

  List<AppMessage> _buildUnifiedUpdates({
    required List<AppMessage> messages,
    required List<DashboardPaymentDto> payments,
    required List<DashboardTenantDto> tenants,
    required int limit,
  }) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    final tenantNameById = <String, String>{
      for (final tenant in tenants) tenant.id: tenant.fullName,
    };

    final paymentUpdates = payments.map((payment) {
      final tenantName =
          tenantNameById[payment.tenantId]?.trim().isNotEmpty == true
          ? tenantNameById[payment.tenantId]!.trim()
          : 'Tenant';
      final amount = payment.status == 'partial' && payment.paidAmount > 0
          ? payment.paidAmount
          : payment.amount;
      final eventTime = payment.paidAt ?? payment.updatedAt;

      String title;
      String severity;
      String type;
      if (payment.status == 'paid') {
        title = 'Payment received from $tenantName';
        severity = 'info';
        type = 'receipt';
      } else if (payment.status == 'partial') {
        title = 'Partial payment from $tenantName';
        severity = 'warn';
        type = 'payment';
      } else {
        title = 'Payment pending for $tenantName';
        severity = 'warn';
        type = 'overdue';
      }

      return AppMessage(
        id: 'payment-${payment.id}',
        type: type,
        title: title,
        body:
            'Amount Rs ${_formatInr(amount)} • ${payment.status.toUpperCase()}',
        severity: severity,
        tenantId: payment.tenantId,
        paymentId: payment.id,
        read: true,
        createdAt: eventTime,
      );
    });

    final tenantUpdates = tenants.map(
      (tenant) => AppMessage(
        id: 'tenant-${tenant.id}',
        type: 'tenant',
        title: 'Tenant added',
        body: '${tenant.fullName} was added to your property records',
        severity: 'info',
        tenantId: tenant.id,
        paymentId: null,
        read: true,
        createdAt: tenant.createdAt,
      ),
    );

    final combined = <AppMessage>[
      ...messages,
      ...paymentUpdates,
      ...tenantUpdates,
    ].where((item) => item.createdAt.isAfter(sevenDaysAgo)).toList();

    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final dedupedById = <String, AppMessage>{};
    for (final item in combined) {
      dedupedById[item.id] = item;
    }

    return dedupedById.values.take(limit).toList(growable: false);
  }

  String _formatInr(int value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    if (digits.length <= 3) return '$sign$digits';

    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];

    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) {
      parts.insert(0, rest);
    }

    return '$sign${parts.join(',')},$last3';
  }

  Future<DashboardSummary> _buildSummary() async {
    final properties = await _service.fetchProperties();
    final payments = await _service.fetchPayments();
    final totalTenants = await _service.fetchTenantCount();

    return _toSummary(
      properties: properties,
      payments: payments,
      totalTenants: totalTenants,
    );
  }

  DashboardSummary _toSummary({
    required List<DashboardPropertyDto> properties,
    required List<DashboardPaymentDto> payments,
    required int totalTenants,
  }) {
    final totalProperties = properties.length;
    final vacantProperties = properties.fold<int>(
      0,
      (sum, property) => sum + property.vacantRooms,
    );

    final now = DateTime.now();
    bool isSameMonth(DateTime date) =>
        date.year == now.year && date.month == now.month;

    int collectedValue(DashboardPaymentDto payment) {
      if (payment.status == 'partial') {
        if (payment.paidAmount > 0) return payment.paidAmount;
        return 0;
      }
      if (payment.status == 'paid') {
        if (payment.paidAmount > 0) return payment.paidAmount;
        return payment.amount;
      }
      return 0;
    }

    bool isCollected(DashboardPaymentDto payment) =>
        payment.status == 'paid' ||
        (payment.status == 'partial' && collectedValue(payment) > 0);

    bool isUpiLike(DashboardPaymentDto payment) {
      final method = payment.method.toLowerCase();
      return method == 'upi' || method == 'online' || method == 'razorpay';
    }

    final collectedPayments = payments
        .where((p) => isCollected(p))
        .where((p) => isSameMonth(p.paidAt ?? p.updatedAt))
        .toList();
    final pendingPayments = payments
        .where((p) => p.status != 'paid')
        .where((p) => isSameMonth(p.dueDate))
        .toList();

    final collectedAmount = collectedPayments.fold<int>(
      0,
      (sum, item) => sum + collectedValue(item),
    );
    final pendingAmount = pendingPayments.fold<int>(
      0,
      (sum, item) => sum + item.amount,
    );

    final pendingTenants = pendingPayments
        .map((item) => item.tenantId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    final cashAmount = collectedPayments
        .where((item) => item.method == 'cash')
        .fold<int>(0, (sum, item) => sum + collectedValue(item));
    final onlineAmount = collectedPayments
        .where((item) => isUpiLike(item))
        .fold<int>(0, (sum, item) => sum + collectedValue(item));

    return DashboardSummary(
      totalProperties: totalProperties,
      vacantProperties: vacantProperties,
      totalTenants: totalTenants,
      collectedAmount: collectedAmount,
      collectedPayments: collectedPayments.length,
      pendingAmount: pendingAmount,
      pendingPayments: pendingPayments.length,
      pendingTenants: pendingTenants,
      cashAmount: cashAmount,
      onlineAmount: onlineAmount,
    );
  }
}
