import '../entities/tenant_entity.dart';

/// Repository interface for tenant management
/// Implements repository pattern for domain independence
abstract class TenantRepository {
  /// Add a new tenant
  Future<void> addTenant(TenantEntity tenant);

  /// Get all tenants for an owner (paginated)
  Future<List<TenantEntity>> getTenantsForOwner(
    String ownerId, {
    required int limit,
    required int page,
    String? filterStatus,
    String? sortBy,
  });

  /// Get specific tenant
  Future<TenantEntity?> getTenant(String tenantId);

  /// Get tenants by property
  Future<List<TenantEntity>> getTenantsByProperty(String propertyId);

  /// Update tenant
  Future<void> updateTenant(TenantEntity tenant);

  /// Deactivate tenant (mark as inactive, never delete)
  Future<void> deactivateTenant(String tenantId);

  /// Activate tenant (reactivate inactive tenant)
  Future<void> activateTenant(String tenantId);

  /// Search tenants by name or phone
  Future<List<TenantEntity>> searchTenants(String ownerId, String query);

  /// Get count of active tenants for owner
  Future<int> getActiveTenantCount(String ownerId);

  /// Get count of overdue tenants
  Future<int> getOverdueTenantCount(String ownerId);

  /// Get total monthly income
  Future<int> getTotalMonthlyIncome(String ownerId);

  /// Get pending/due amount
  Future<int> getPendingAmount(String ownerId);
}
