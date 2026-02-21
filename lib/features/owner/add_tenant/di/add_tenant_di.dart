import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/add_tenant/data/repositories/add_tenant_repository_impl.dart';
import 'package:rentdone/features/owner/add_tenant/data/services/add_tenant_firebase_service.dart';
import 'package:rentdone/features/owner/add_tenant/domain/repositories/add_tenant.dart';
import 'package:rentdone/features/owner/add_tenant/domain/usecases/add_tenant_usecases.dart';

final addTenantFirebaseServiceProvider =
    Provider<AddTenantFirebaseService>((ref) {
  return AddTenantFirebaseService();
});

final addTenantRepositoryProvider = Provider<TenantRepository>((ref) {
  final service = ref.watch(addTenantFirebaseServiceProvider);
  return AddTenantRepositoryImpl(service);
});

final addTenantUseCaseProvider = Provider<AddTenantUseCase>((ref) {
  final repo = ref.read(addTenantRepositoryProvider);
  return AddTenantUseCase(repo);
});
