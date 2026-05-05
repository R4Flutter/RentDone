import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owners_properties/data/repositories/property_repository_impl.dart';
import 'package:rentdone/features/owner/owners_properties/data/repositories/tenant_repository_impl.dart';
import 'package:rentdone/features/owner/owners_properties/data/services/property_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/data/services/tenant_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/tenant_repository.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/add_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/delete_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/get_tenant_by_id.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/remove_tenant_from_room.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/update_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_all_properties.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_all_tenants.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_property_tenants.dart';

// Services
final propertyFirebaseServiceProvider = Provider<PropertyFirebaseService>((ref) => PropertyFirebaseService());
final tenantFirebaseServiceProvider = Provider<TenantFirebaseService>((ref) => TenantFirebaseService());

// Repositories
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  return PropertyRepositoryImpl(ref.watch(propertyFirebaseServiceProvider));
});

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepositoryImpl(ref.watch(tenantFirebaseServiceProvider));
});

// Property Use Cases
final watchAllPropertiesUseCaseProvider = Provider<WatchAllPropertiesUseCase>((ref) {
  return WatchAllPropertiesUseCase(ref.watch(propertyRepositoryProvider));
});

final watchPropertyUseCaseProvider = Provider<WatchPropertyUseCase>((ref) {
  return WatchPropertyUseCase(ref.watch(propertyRepositoryProvider));
});

final addPropertyUseCaseProvider = Provider<AddPropertyUseCase>((ref) {
  return AddPropertyUseCase(ref.watch(propertyRepositoryProvider));
});

final updatePropertyUseCaseProvider = Provider<UpdatePropertyUseCase>((ref) {
  return UpdatePropertyUseCase(ref.watch(propertyRepositoryProvider));
});

final deletePropertyUseCaseProvider = Provider<DeletePropertyUseCase>((ref) {
  return DeletePropertyUseCase(ref.watch(propertyRepositoryProvider));
});

// Tenant Use Cases
final watchAllTenantsUseCaseProvider = Provider<WatchAllTenantsUseCase>((ref) {
  return WatchAllTenantsUseCase(ref.watch(tenantRepositoryProvider));
});

final watchPropertyTenantsUseCaseProvider = Provider<WatchPropertyTenantsUseCase>((ref) {
  return WatchPropertyTenantsUseCase(ref.watch(tenantRepositoryProvider));
});

final getTenantByIdUseCaseProvider = Provider<GetTenantByIdUseCase>((ref) {
  return GetTenantByIdUseCase(ref.watch(tenantRepositoryProvider));
});

final removeTenantFromRoomUseCaseProvider = Provider<RemoveTenantFromRoomUseCase>((ref) {
  return RemoveTenantFromRoomUseCase(ref.watch(tenantRepositoryProvider));
});
