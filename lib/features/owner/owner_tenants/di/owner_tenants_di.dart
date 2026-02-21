import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_tenants/data/repositories/owner_tenants_repository_impl.dart';
import 'package:rentdone/features/owner/owner_tenants/data/services/owner_tenants_firebase_service.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/repositories/owner_tenants_repository.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/usecases/watch_owner_tenant_properties.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/usecases/watch_owner_tenants.dart';

final ownerTenantsFirebaseServiceProvider =
    Provider<OwnerTenantsFirebaseService>((ref) {
      return OwnerTenantsFirebaseService();
    });

final ownerTenantsRepositoryProvider = Provider<OwnerTenantsRepository>((ref) {
  final service = ref.watch(ownerTenantsFirebaseServiceProvider);
  return OwnerTenantsRepositoryImpl(service);
});

final watchOwnerTenantsUseCaseProvider = Provider<WatchOwnerTenants>((ref) {
  final repository = ref.watch(ownerTenantsRepositoryProvider);
  return WatchOwnerTenants(repository);
});

final watchOwnerTenantPropertiesUseCaseProvider =
    Provider<WatchOwnerTenantProperties>((ref) {
      final repository = ref.watch(ownerTenantsRepositoryProvider);
      return WatchOwnerTenantProperties(repository);
    });
