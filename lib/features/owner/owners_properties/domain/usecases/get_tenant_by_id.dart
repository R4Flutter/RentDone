import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class GetTenantByIdUseCase {
  final PropertyRepository _repository;

  const GetTenantByIdUseCase(this._repository);

  Future<Tenant?> call(String tenantId) {
    return _repository.getTenantById(tenantId);
  }
}
