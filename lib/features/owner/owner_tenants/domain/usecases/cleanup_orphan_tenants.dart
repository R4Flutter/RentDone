import 'package:rentdone/features/owner/owner_tenants/domain/repositories/owner_tenants_repository.dart';

class CleanupOrphanTenants {
  final OwnerTenantsRepository _repository;

  const CleanupOrphanTenants(this._repository);

  Future<int> call() {
    return _repository.cleanupOrphanTenants();
  }
}
