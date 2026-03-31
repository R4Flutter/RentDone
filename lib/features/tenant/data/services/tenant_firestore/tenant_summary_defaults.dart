import 'package:intl/intl.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

class TenantSummaryDefaults {
  static TenantDashboardSummary empty({
    required Map<String, dynamic> userData,
    String? email,
  }) {
    return TenantDashboardSummary(
      tenantId: '',
      tenantName: userData['name'] as String? ?? 'Tenant',
      tenantEmail:
          userData['email'] as String? ??
          userData['emailLowercase'] as String? ??
          (email ?? ''),
      tenantPhone: userData['phone'] as String? ?? '',
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
      currentMonthName: DateFormat.MMMM().format(DateTime.now()),
      profileImageUrl: userData['photoUrl'] as String?,
      trustScore: TenantTrustScore.defaultScore,
      trustBadge: TenantTrustScore.badgeFor(
        TenantTrustScore.defaultScore,
      ).label,
      onTimePaymentRate: 0,
      latePaymentRate: 0,
      tenureYears: 0,
    );
  }
}
