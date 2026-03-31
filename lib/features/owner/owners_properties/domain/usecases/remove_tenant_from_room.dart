import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class RemoveTenantFromRoomUseCase {
  final PropertyRepository _repository;

  const RemoveTenantFromRoomUseCase(this._repository);

  Future<void> call({
    required String tenantId,
    required String propertyId,
    required String roomId,
  }) {
    return _repository.removeTenant(
      tenantId: tenantId,
      propertyId: propertyId,
      roomId: roomId,
    );
  }
}
