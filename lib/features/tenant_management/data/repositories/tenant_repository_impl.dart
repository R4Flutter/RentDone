import '../../domain/entities/tenant_entity.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../models/tenant_dto.dart';
import '../services/tenant_firestore_service.dart';

/// Implementation of TenantRepository
/// Uses TenantFirestoreService for data access
class TenantRepositoryImpl implements TenantRepository {
  final TenantFirestoreService _firebaseService;

  TenantRepositoryImpl(this._firebaseService);

  @override
  Future<void> addTenant(TenantEntity tenant) async {
    try {
      final dto = TenantDTO.fromEntity(tenant);
      await _firebaseService.addTenant(dto);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TenantEntity>> getTenantsForOwner(
    String ownerId, {
    required int limit,
    required int page,
    String? filterStatus,
    String? sortBy,
  }) async {
    try {
      final dtos = await _firebaseService.getTenantsForOwner(
        ownerId,
        limit: limit,
        page: page,
        filterStatus: filterStatus,
        sortBy: sortBy,
      );
      return dtos.map((dto) => dto.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TenantEntity?> getTenant(String tenantId) async {
    try {
      final dto = await _firebaseService.getTenant(tenantId);
      return dto?.toEntity();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TenantEntity>> getTenantsByProperty(String propertyId) async {
    try {
      final dtos = await _firebaseService.getTenantsByProperty(propertyId);
      return dtos.map((dto) => dto.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateTenant(TenantEntity tenant) async {
    try {
      final dto = TenantDTO.fromEntity(tenant);
      await _firebaseService.updateTenant(dto);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deactivateTenant(String tenantId) async {
    try {
      await _firebaseService.deactivateTenant(tenantId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> activateTenant(String tenantId) async {
    try {
      await _firebaseService.activateTenant(tenantId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<TenantEntity>> searchTenants(String ownerId, String query) async {
    try {
      final dtos = await _firebaseService.searchTenants(ownerId, query);
      return dtos.map((dto) => dto.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getActiveTenantCount(String ownerId) async {
    try {
      return await _firebaseService.getActiveTenantCount(ownerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getOverdueTenantCount(String ownerId) async {
    try {
      return await _firebaseService.getOverdueTenantCount(ownerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getTotalMonthlyIncome(String ownerId) async {
    try {
      return await _firebaseService.getTotalMonthlyIncome(ownerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getPendingAmount(String ownerId) async {
    try {
      return await _firebaseService.getPendingAmount(ownerId);
    } catch (e) {
      rethrow;
    }
  }
}
