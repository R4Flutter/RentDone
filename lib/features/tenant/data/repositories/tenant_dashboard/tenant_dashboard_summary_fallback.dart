import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

String resolveTenantPhone({String? summaryPhone, String? authPhone}) {
  final normalizedSummary = (summaryPhone ?? '').trim();
  if (normalizedSummary.isNotEmpty) return normalizedSummary;
  final normalizedAuthPhone = (authPhone ?? '').trim();
  return normalizedAuthPhone.isNotEmpty ? normalizedAuthPhone : '';
}

TenantDashboardSummary permissionDeniedSummary(User user) {
  return TenantDashboardSummary(
    tenantId: '',
    tenantName: user.displayName ?? 'Tenant',
    tenantEmail: user.email ?? '',
    tenantPhone: user.phoneNumber ?? '',
    ownerId: '',
    roomNumber: '-',
    propertyName: '',
    monthlyRent: 0,
    depositAmount: null,
    allocationDate: null,
    rentDueDay: 1,
    ownerPhoneNumber: '',
    dueAmount: 0,
    lifetimePaid: 0,
    currentMonthName: '',
    profileImageUrl: user.photoURL,
    trustScore: 50,
    trustBadge: 'Average Tenant',
    onTimePaymentRate: 0,
    latePaymentRate: 0,
    tenureYears: 0,
  );
}
