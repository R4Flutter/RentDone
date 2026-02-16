import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

abstract class TenantRepository {
  Future<void> addTenant(Tenant tenant);
}
