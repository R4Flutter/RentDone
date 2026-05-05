import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/tenant_repository.dart';

class GetTenantByIdUseCase {
  final TenantRepository repository;

  GetTenantByIdUseCase(this.repository);

  Future<Tenant?> call(String tenantId) {
    return repository.getTenantById(tenantId);
  }
}
