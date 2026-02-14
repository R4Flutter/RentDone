import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';
import 'package:rentdone/features/owner/owners_properties/data/serices/firestore_services.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';

// ===== FIRESTORE SERVICE PROVIDER =====
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// ===== PROPERTY PROVIDERS =====

/// Stream of all properties
final allPropertiesProvider = StreamProvider<List<Property>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getAllProperties();
});

/// Stream of a single property by ID
final propertyProvider = StreamProvider.family<Property, String>((
  ref,
  propertyId,
) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getPropertyStream(propertyId);
});

// ===== TENANT PROVIDERS =====

/// Stream of all tenants
final allTenantsProvider = StreamProvider<List<Tenant>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getAllTenants();
});

/// Stream of tenants for a specific property
final propertyTenantsProvider = StreamProvider.family<List<Tenant>, String>((
  ref,
  propertyId,
) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getTenantsForProperty(propertyId);
});

// ===== TENANT STATE MANAGEMENT =====

/// State for add/remove tenant operations
class TenantActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;

  const TenantActionState({
    this.isLoading = false,
    this.successMessage,
    this.errorMessage,
  });

  TenantActionState copyWith({
    bool? isLoading,
    String? successMessage,
    String? errorMessage,
  }) {
    return TenantActionState(
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }

  void reset() {
    // This will be handled by the notifier
  }
}

// ===== ADD TENANT NOTIFIER =====

class AddTenantNotifier extends Notifier<TenantActionState> {
  late final FirestoreService _firestoreService;

  @override
  TenantActionState build() {
    _firestoreService = ref.watch(firestoreServiceProvider);
    return const TenantActionState();
  }

  /// Add a new tenant to the database
  Future<void> addTenant(Tenant tenant) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      await _firestoreService.addTenant(tenant);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Tenant added successfully!',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Reset the state
  void reset() {
    state = const TenantActionState();
  }
}

/// Provider for add tenant notifier
final addTenantNotifierProvider =
    NotifierProvider<AddTenantNotifier, TenantActionState>(() {
      return AddTenantNotifier();
    });

// ===== REMOVE TENANT NOTIFIER =====

class RemoveTenantNotifier extends Notifier<TenantActionState> {
  late final FirestoreService _firestoreService;

  @override
  TenantActionState build() {
    _firestoreService = ref.watch(firestoreServiceProvider);
    return const TenantActionState();
  }

  /// Remove a tenant and mark room as vacant
  Future<void> removeTenant(
    String tenantId,
    String propertyId,
    String roomId,
  ) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      await _firestoreService.removeTenant(tenantId, propertyId, roomId);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Tenant removed and room marked as vacant',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Reset the state
  void reset() {
    state = const TenantActionState();
  }
}

/// Provider for remove tenant notifier
final removeTenantNotifierProvider =
    NotifierProvider<RemoveTenantNotifier, TenantActionState>(() {
      return RemoveTenantNotifier();
    });

/// Fetch a tenant by id (one-time future)
final tenantByIdProvider = FutureProvider.family<Tenant?, String>((
  ref,
  id,
) async {
  final service = ref.watch(firestoreServiceProvider);
  return service.getTenant(id);
});
