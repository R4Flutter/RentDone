import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owners_properties/data/repositories/property_repository_impl.dart';
import 'package:rentdone/features/owner/owners_properties/data/services/property_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/add_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/delete_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/get_tenant_by_id.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/remove_tenant_from_room.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/update_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_all_properties.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_all_tenants.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/watch_property_tenants.dart';

// ===== DATA/DOMAIN COMPOSITION =====

final propertyFirebaseServiceProvider = Provider<PropertyFirebaseService>((ref) {
  return PropertyFirebaseService();
});

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  final service = ref.watch(propertyFirebaseServiceProvider);
  return PropertyRepositoryImpl(service);
});

final watchAllPropertiesUseCaseProvider = Provider<WatchAllPropertiesUseCase>((
  ref,
) {
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

final watchAllTenantsUseCaseProvider = Provider<WatchAllTenantsUseCase>((ref) {
  return WatchAllTenantsUseCase(ref.watch(propertyRepositoryProvider));
});

final watchPropertyTenantsUseCaseProvider =
    Provider<WatchPropertyTenantsUseCase>((ref) {
      return WatchPropertyTenantsUseCase(ref.watch(propertyRepositoryProvider));
    });

final getTenantByIdUseCaseProvider = Provider<GetTenantByIdUseCase>((ref) {
  return GetTenantByIdUseCase(ref.watch(propertyRepositoryProvider));
});

final removeTenantFromRoomUseCaseProvider =
    Provider<RemoveTenantFromRoomUseCase>((ref) {
      return RemoveTenantFromRoomUseCase(ref.watch(propertyRepositoryProvider));
    });

// ===== UI READ PROVIDERS =====

final allPropertiesProvider = StreamProvider<List<Property>>((ref) {
  final useCase = ref.watch(watchAllPropertiesUseCaseProvider);
  return useCase();
});

final propertyProvider = StreamProvider.family<Property, String>((
  ref,
  propertyId,
) {
  final useCase = ref.watch(watchPropertyUseCaseProvider);
  return useCase(propertyId);
});

final allTenantsProvider = StreamProvider<List<Tenant>>((ref) {
  final useCase = ref.watch(watchAllTenantsUseCaseProvider);
  return useCase();
});

final propertyTenantsProvider = StreamProvider.family<List<Tenant>, String>((
  ref,
  propertyId,
) {
  final useCase = ref.watch(watchPropertyTenantsUseCaseProvider);
  return useCase(propertyId);
});

final tenantByIdProvider = FutureProvider.family<Tenant?, String>((ref, id) {
  final useCase = ref.watch(getTenantByIdUseCaseProvider);
  return useCase(id);
});

// ===== ACTION STATE =====

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
}

class RemoveTenantNotifier extends Notifier<TenantActionState> {
  late final RemoveTenantFromRoomUseCase _useCase;

  @override
  TenantActionState build() {
    _useCase = ref.watch(removeTenantFromRoomUseCaseProvider);
    return const TenantActionState();
  }

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
      await _useCase(
        tenantId: tenantId,
        propertyId: propertyId,
        roomId: roomId,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Tenant removed and room marked as vacant',
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  void reset() {
    state = const TenantActionState();
  }
}

final removeTenantNotifierProvider =
    NotifierProvider<RemoveTenantNotifier, TenantActionState>(
  RemoveTenantNotifier.new,
);
