import 'package:intl/intl.dart';
import 'package:rentdone/core/trust/tenant_trust_score.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

import 'tenant_dashboard_metrics.dart';
import 'tenant_dashboard_payment_docs.dart';

class TenantDashboardSummaryFactory {
  static TenantDashboardSummary build({
    required String tenantId,
    required Map<String, dynamic> tenantData,
    required Map<String, dynamic> userData,
    required List paymentDocs,
    required TenantRoomDetails? roomDetails,
    required TenantOwnerDetails? ownerDetails,
    String? email,
  }) {
    final trustScore = TenantTrustScore.clamp(
      (tenantData['trustScore'] as num?)?.toInt() ??
          TenantTrustScore.defaultScore,
    );
    final dueDay =
        (tenantData['rentDueDay'] as num?)?.toInt() ??
        (tenantData['rentDueDate'] as num?)?.toInt() ??
        1;
    final rates = TenantDashboardMetrics.paymentRates(
      paymentDocs: paymentDocs.cast(),
      dueDay: dueDay,
      onTimePayments: (tenantData['onTimePayments'] as num?)?.toInt(),
      latePayments: (tenantData['latePayments'] as num?)?.toInt(),
    );
    return TenantDashboardSummary(
      tenantId: tenantId,
      tenantName: tenantData['name'] as String? ?? 'Tenant',
      tenantEmail:
          tenantData['email'] as String? ??
          tenantData['emailLowercase'] as String? ??
          (email ?? ''),
      tenantPhone: TenantDashboardMetrics.tenantPhone(tenantData, userData),
      ownerId: tenantData['ownerId'] as String? ?? '',
      roomNumber:
          roomDetails?.roomNumber ??
          (tenantData['roomNumber'] as String? ?? '-'),
      propertyName:
          roomDetails?.propertyName ??
          (tenantData['propertyName'] as String? ?? ''),
      monthlyRent:
          roomDetails?.monthlyRent ??
          ((tenantData['rentAmount'] as num?)?.toInt() ?? 0),
      depositAmount:
          roomDetails?.depositAmount ??
          ((tenantData['depositAmount'] as num?)?.toInt()),
      allocationDate: roomDetails?.allocationDate,
      rentDueDay: roomDetails?.rentDueDay ?? dueDay,
      ownerPhoneNumber:
          ownerDetails?.ownerPhoneNumber ??
          (tenantData['ownerPhoneNumber'] as String? ?? ''),
      dueAmount: (tenantData['dueAmount'] as num?)?.toInt() ?? 0,
      lifetimePaid:
          (tenantData['totalPaid'] as num?)?.toInt() ??
          TenantDashboardPaymentDocs.dynamicTotal(paymentDocs.cast()),
      currentMonthName: DateFormat.MMMM().format(DateTime.now()),
      profileImageUrl: tenantData['profileImageUrl'] as String?,
      trustScore: trustScore,
      trustBadge:
          (tenantData['trustBadge'] as String?)?.trim().isNotEmpty == true
          ? (tenantData['trustBadge'] as String).trim()
          : TenantTrustScore.badgeFor(trustScore).label,
      onTimePaymentRate: rates.onTimeRate,
      latePaymentRate: rates.lateRate,
      tenureYears: TenantDashboardMetrics.tenureYears(tenantData, roomDetails),
    );
  }
}
