// tenant_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';


class TenantRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> addTenant(Tenant tenant) async {
    await _db.collection('tenants').doc(tenant.id).set(tenant.toMap());
  }
}