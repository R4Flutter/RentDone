import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

import 'tenant_dashboard_payment_docs.dart';
import 'tenant_dashboard_summary_factory.dart';
import 'tenant_owner_details_reader.dart';
import 'tenant_room_details_reader.dart';
import 'tenant_summary_defaults.dart';
import 'tenant_summary_seed_resolver.dart';

class TenantDashboardSummaryLoader {
  final FirebaseFirestore firestore;

  const TenantDashboardSummaryLoader(this.firestore);

  Future<TenantDashboardSummary> load({
    required String uid,
    String? email,
  }) async {
    final seed = await TenantSummarySeedResolver(firestore).resolve(uid);
    if (seed.tenantData == null) {
      return TenantSummaryDefaults.empty(userData: seed.userData, email: email);
    }

    final tenantId = seed.tenantId ?? uid;
    final roomDetails = await _safeRoomDetails(tenantId);
    final ownerDetails = await _safeOwnerDetails(tenantId);
    final paymentDocs = await TenantDashboardPaymentDocs.load(
      firestore,
      tenantId,
    );
    return TenantDashboardSummaryFactory.build(
      tenantId: tenantId,
      tenantData: seed.tenantData!,
      userData: seed.userData,
      paymentDocs: paymentDocs,
      roomDetails: roomDetails,
      ownerDetails: ownerDetails,
      email: email,
    );
  }

  Future<TenantRoomDetails?> _safeRoomDetails(String tenantId) async {
    try {
      return await TenantRoomDetailsReader(firestore).get(tenantId);
    } on FirebaseException {
      return null;
    }
  }

  Future<TenantOwnerDetails?> _safeOwnerDetails(String tenantId) async {
    try {
      return await TenantOwnerDetailsReader(firestore).get(tenantId);
    } on FirebaseException {
      return null;
    }
  }
}
