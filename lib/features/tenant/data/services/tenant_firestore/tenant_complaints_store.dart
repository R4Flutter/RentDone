import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_complaint.dart';

class TenantComplaintsStore {
  final FirebaseFirestore firestore;

  const TenantComplaintsStore(this.firestore);

  Future<void> save({
    required String tenantId,
    required TenantComplaint complaint,
  }) => firestore
      .collection('tenants')
      .doc(tenantId)
      .collection('complaints')
      .add(complaint.toFirestore());
}
