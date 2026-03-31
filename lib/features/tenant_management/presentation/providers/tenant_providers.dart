import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../domain/usecases/tenant_usecases.dart';

/// Provider: Get all tenants for owner (paginated)
final tenantsProvider =
    FutureProvider.family<
      List<TenantEntity>,
      ({String ownerId, int page, String? filterStatus})
    >((ref, params) async {
      final useCase = ref.watch(getTenantsUseCaseProvider);
      return useCase.call(
        params.ownerId,
        limit: 20,
        page: params.page,
        filterStatus: params.filterStatus,
        sortBy: 'createdAt',
      );
    });

/// Provider: Get single tenant
final tenantProvider = FutureProvider.family<TenantEntity?, String>((
  ref,
  tenantId,
) async {
  final useCase = ref.watch(getTenantUseCaseProvider);
  return useCase.call(tenantId);
});

/// Provider: Search tenants
final searchTenantsProvider =
    FutureProvider.family<List<TenantEntity>, ({String ownerId, String query})>(
      (ref, params) async {
        final useCase = ref.watch(searchTenantsUseCaseProvider);
        return useCase.call(params.ownerId, params.query);
      },
    );

/// Provider: Tenant analytics
final tenantAnalyticsProvider =
    FutureProvider.family<
      ({int activeTenants, int overdueCount, int monthlyIncome, int pending}),
      String
    >((ref, ownerId) async {
      final useCase = ref.watch(getTenantAnalyticsUseCaseProvider);
      return useCase.call(ownerId);
    });

/// Notifier for managing tenants (add, update, deactivate)
class TenantNotifier extends Notifier<AsyncValue<void>> {
  late AddTenantUseCase _addUseCase;
  late UpdateTenantUseCase _updateUseCase;
  late DeactivateTenantUseCase _deactivateUseCase;

  @override
  AsyncValue<void> build() {
    _addUseCase = ref.watch(addTenantUseCaseProvider);
    _updateUseCase = ref.watch(updateTenantUseCaseProvider);
    _deactivateUseCase = ref.watch(deactivateTenantUseCaseProvider);
    return const AsyncValue.data(null);
  }

  Future<void> addTenant(TenantEntity tenant) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _addUseCase.call(tenant));
  }

  Future<void> updateTenant(TenantEntity tenant) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _updateUseCase.call(tenant));
  }

  Future<void> deactivateTenant(String tenantId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _deactivateUseCase.call(tenantId));
  }
}

final tenantNotifierProvider =
    NotifierProvider<TenantNotifier, AsyncValue<void>>(() {
      return TenantNotifier();
    });
