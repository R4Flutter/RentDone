import 'package:rentdone/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/dashboard_repository.dart';

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
  Stream<List<AppMessage>> watchRecentMessages({int limit = 6}) {
    return _service.watchRecentMessages(limit: limit).map(
          (items) => items.map((item) => item.toEntity()).toList(),
        );
  }

  Future<DashboardSummary> _buildSummary() async {
    final properties = await _service.fetchProperties();
    final payments = await _service.fetchPayments();
    final totalTenants = await _service.fetchTenantCount();

    final totalProperties = properties.length;
    final vacantProperties = properties.where((p) => p.vacantRooms > 0).length;

    final now = DateTime.now();
    bool isSameMonth(DateTime date) =>
        date.year == now.year && date.month == now.month;

    final collectedPayments = payments
        .where((p) => p.status == 'paid')
        .where((p) => isSameMonth(p.paidAt ?? p.updatedAt))
        .toList();
    final pendingPayments = payments
        .where((p) => p.status != 'paid')
        .where((p) => isSameMonth(p.dueDate))
        .toList();

    final collectedAmount =
        collectedPayments.fold<int>(0, (sum, item) => sum + item.amount);
    final pendingAmount =
        pendingPayments.fold<int>(0, (sum, item) => sum + item.amount);

    final pendingTenants = pendingPayments
        .map((item) => item.tenantId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    final cashAmount = collectedPayments
        .where((item) => item.method == 'cash')
        .fold<int>(0, (sum, item) => sum + item.amount);
    final onlineAmount = collectedPayments
        .where((item) => item.method == 'online')
        .fold<int>(0, (sum, item) => sum + item.amount);

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
