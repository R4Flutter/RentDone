import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/tenant_repository.dart';

class AddTenantToRoomUseCase {
  final TenantRepository repository;

  AddTenantToRoomUseCase(this.repository);

  Future<void> call(Tenant tenant) {
    return repository.addTenant(tenant);
  }
}
