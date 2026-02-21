import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_tenants/di/owner_tenants_di.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

final ownerTenantsProvider = StreamProvider<List<Tenant>>((ref) {
  final useCase = ref.watch(watchOwnerTenantsUseCaseProvider);
  return useCase();
});

final ownerTenantPropertiesProvider = StreamProvider<List<Property>>((ref) {
  final useCase = ref.watch(watchOwnerTenantPropertiesUseCaseProvider);
  return useCase();
});
