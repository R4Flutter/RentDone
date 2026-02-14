

import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';
import 'package:rentdone/features/owner/owners_properties/data/serices/firestore_services.dart';

class TenantRepository {
  final FirestoreService _firestoreService;

  TenantRepository(this._firestoreService);

  Future<void> addTenant(Tenant tenant) async {
    await _firestoreService.addTenant(tenant);
  }

  Future<void> removeTenant(
    String tenantId,
    String propertyId,
    String roomId,
  ) async {
    await _firestoreService.removeTenant(tenantId, propertyId, roomId);
  }

  Future<void> updateTenant(Tenant tenant) async {
    await _firestoreService.updateTenant(tenant);
  }
}
