import 'package:rentdone/features/owner/owners_properties/domain/repositories/tenant_repository.dart';

class RemoveTenantFromRoomUseCase {
  final TenantRepository repository;

  RemoveTenantFromRoomUseCase(this.repository);

  Future<void> call({
    required String propertyId,
    required String roomId,
    required String tenantId,
  }) {
    return repository.removeTenantFromRoom(
      propertyId: propertyId,
      roomId: roomId,
      tenantId: tenantId,
    );
  }
}
