import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

import 'tenant_dashboard_auto_link_helper.dart';
import 'tenant_dashboard_summary_fallback.dart';

class TenantDashboardSummaryResolver {
  final FirebaseFunctions functions;
  final TenantFirestoreService firestoreService;

  const TenantDashboardSummaryResolver({
    required this.functions,
    required this.firestoreService,
  });

  Future<TenantDashboardSummary> resolve(User user) async {
    final authEmail = (user.email ?? '').trim();
    if (authEmail.isNotEmpty) {
      try {
        await firestoreService.ensureTenantUserDoc(
          uid: user.uid,
          email: authEmail,
        );
      } on FirebaseException {
        // Best-effort sync before reading the tenant dashboard.
      }
    }

    final summary = await firestoreService.getDashboardSummary(
      uid: user.uid,
      email: user.email,
    );

    final resolved = await TenantDashboardAutoLinkHelper(
      functions: functions,
      firestoreService: firestoreService,
    ).resolve(user, summary);

    return TenantDashboardSummary(
      tenantId: resolved.tenantId,
      tenantName: resolved.tenantName,
      tenantEmail: authEmail.isNotEmpty ? authEmail : resolved.tenantEmail,
      tenantPhone: resolveTenantPhone(
        summaryPhone: resolved.tenantPhone,
        authPhone: user.phoneNumber,
      ),
      ownerId: resolved.ownerId,
      roomNumber: resolved.roomNumber,
      propertyName: resolved.propertyName,
      monthlyRent: resolved.monthlyRent,
      depositAmount: resolved.depositAmount,
      allocationDate: resolved.allocationDate,
      rentDueDay: resolved.rentDueDay,
      ownerPhoneNumber: resolved.ownerPhoneNumber,
      dueAmount: resolved.dueAmount,
      lifetimePaid: resolved.lifetimePaid,
      currentMonthName: resolved.currentMonthName,
      profileImageUrl: user.photoURL ?? resolved.profileImageUrl,
      trustScore: resolved.trustScore,
      trustBadge: resolved.trustBadge,
      onTimePaymentRate: resolved.onTimePaymentRate,
      latePaymentRate: resolved.latePaymentRate,
      tenureYears: resolved.tenureYears,
    );
  }
}
