import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

import 'tenant_dashboard_summary_loader.dart';

mixin TenantFirestoreSummaryMixin {
  FirebaseFirestore get firestore;

  Future<TenantDashboardSummary> getDashboardSummary({
    required String uid,
    String? email,
  }) => TenantDashboardSummaryLoader(firestore).load(uid: uid, email: email);
}
