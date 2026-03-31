import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../../data/di/tenant_management_di.dart';

/// Use case: Get all tenants for owner (paginated)
final getTenantsUseCaseProvider = Provider<GetTenantsUseCase>((ref) {
  final repository = ref.watch(tenantRepositoryProvider);
  return GetTenantsUseCase(repository);
});

class GetTenantsUseCase {
  final TenantRepository _repository;

  GetTenantsUseCase(this._repository);

  Future<List<TenantEntity>> call(
    String ownerId, {
    required int limit,
    required int page,
    String? filterStatus,
    String? sortBy,
  }) {
    return _repository.getTenantsForOwner(
      ownerId,
      limit: limit,
      page: page,
      filterStatus: filterStatus,
      sortBy: sortBy,
    );
  }
}

/// Use case: Get specific tenant
final getTenantUseCaseProvider = Provider<GetTenantUseCase>((ref) {
  final repository = ref.watch(tenantRepositoryProvider);
  return GetTenantUseCase(repository);
});

class GetTenantUseCase {
  final TenantRepository _repository;

  GetTenantUseCase(this._repository);

  Future<TenantEntity?> call(String tenantId) {
    return _repository.getTenant(tenantId);
  }
}

/// Use case: Add tenant
final addTenantUseCaseProvider = Provider<AddTenantUseCase>((ref) {
  final repository = ref.watch(tenantRepositoryProvider);
  return AddTenantUseCase(repository);
});

class AddTenantUseCase {
  final TenantRepository _repository;

  AddTenantUseCase(this._repository);

  Future<void> call(TenantEntity tenant) {
    return _repository.addTenant(tenant);
  }
}

/// Use case: Update tenant
final updateTenantUseCaseProvider = Provider<UpdateTenantUseCase>((ref) {
  final repository = ref.watch(tenantRepositoryProvider);
  return UpdateTenantUseCase(repository);
});

class UpdateTenantUseCase {
  final TenantRepository _repository;

  UpdateTenantUseCase(this._repository);

  Future<void> call(TenantEntity tenant) {
    return _repository.updateTenant(tenant);
  }
}

/// Use case: Deactivate tenant
final deactivateTenantUseCaseProvider = Provider<DeactivateTenantUseCase>((
  ref,
) {
  final repository = ref.watch(tenantRepositoryProvider);
  return DeactivateTenantUseCase(repository);
});

class DeactivateTenantUseCase {
  final TenantRepository _repository;

  DeactivateTenantUseCase(this._repository);

  Future<void> call(String tenantId) {
    return _repository.deactivateTenant(tenantId);
  }
}

/// Use case: Search tenants
final searchTenantsUseCaseProvider = Provider<SearchTenantsUseCase>((ref) {
  final repository = ref.watch(tenantRepositoryProvider);
  return SearchTenantsUseCase(repository);
});

class SearchTenantsUseCase {
  final TenantRepository _repository;

  SearchTenantsUseCase(this._repository);

  Future<List<TenantEntity>> call(String ownerId, String query) {
    return _repository.searchTenants(ownerId, query);
  }
}

/// Use case: Get analytics
final getTenantAnalyticsUseCaseProvider = Provider<GetTenantAnalyticsUseCase>((
  ref,
) {
  final repository = ref.watch(tenantRepositoryProvider);
  return GetTenantAnalyticsUseCase(repository);
});

class GetTenantAnalyticsUseCase {
  final TenantRepository _repository;

  GetTenantAnalyticsUseCase(this._repository);

  Future<
    ({int activeTenants, int overdueCount, int monthlyIncome, int pending})
  >
  call(String ownerId) async {
    final activeTenants = await _repository.getActiveTenantCount(ownerId);
    final overdueCount = await _repository.getOverdueTenantCount(ownerId);
    final monthlyIncome = await _repository.getTotalMonthlyIncome(ownerId);
    final pending = await _repository.getPendingAmount(ownerId);

    return (
      activeTenants: activeTenants,
      overdueCount: overdueCount,
      monthlyIncome: monthlyIncome,
      pending: pending,
    );
  }
}
