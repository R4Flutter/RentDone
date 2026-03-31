import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_summary_fallback.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_summary_resolver.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

mixin TenantDashboardSummaryMixin {
  FirebaseAuth get auth;
  FirebaseFunctions get functions;
  TenantFirestoreService get firestoreService;

  Future<TenantDashboardSummary> getDashboardSummary() async {
    final user = auth.currentUser;
    if (user == null) return TenantDashboardSummary.empty;
    try {
      return await TenantDashboardSummaryResolver(
        functions: functions,
        firestoreService: firestoreService,
      ).resolve(user);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return permissionDeniedSummary(user);
      }
      rethrow;
    }
  }
}
