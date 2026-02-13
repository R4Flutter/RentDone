import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/add_tenant/domain/repositories/add_tenant.dart';
import 'package:rentdone/features/owner/add_tenant/domain/usecases/add_tenant_usecases.dart';

// Repository Provider (to be implemented in data layer later)
final addTenantRepositoryProvider =
    Provider<TenantRepository>((ref) {
  throw UnimplementedError();
});

// UseCase Provider
final addTenantUseCaseProvider =
    Provider<AddTenantUseCase>((ref) {
  final repo = ref.read(addTenantRepositoryProvider);
  return AddTenantUseCase(repo);
});