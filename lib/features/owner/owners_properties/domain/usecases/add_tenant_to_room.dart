import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class AddTenantToRoomUseCase {
  final PropertyRepository _repository;

  const AddTenantToRoomUseCase(this._repository);

  Future<void> call(Tenant tenant) {
    return _repository.addTenant(tenant);
  }
}
