import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/owner/owners_properties/di/property_di.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/usecases/remove_tenant_from_room.dart';

export 'package:rentdone/features/owner/owners_properties/di/property_di.dart'
    show
        addPropertyUseCaseProvider,
        updatePropertyUseCaseProvider,
        deletePropertyUseCaseProvider,
        getTenantByIdUseCaseProvider;

// ===== UI READ PROVIDERS =====

final allPropertiesProvider = StreamProvider<List<Property>>((ref) {
  final useCase = ref.watch(watchAllPropertiesUseCaseProvider);
  return useCase.call();
});

final propertyProvider = StreamProvider.family<Property, String>((
  ref,
  propertyId,
) {
  final useCase = ref.watch(watchPropertyUseCaseProvider);
  return useCase.call(propertyId);
});

final allTenantsProvider = StreamProvider<List<Tenant>>((ref) {
  final useCase = ref.watch(watchAllTenantsUseCaseProvider);
  final user = ref.watch(firebaseAuthProvider).currentUser;
  
  if (user == null || user.uid.isEmpty) {
    return Stream.value([]);
  }
  
  return useCase.call(user.uid);
});

final propertyTenantsProvider = StreamProvider.family<List<Tenant>, String>((
  ref,
  propertyId,
) {
  final useCase = ref.watch(watchPropertyTenantsUseCaseProvider);
  return useCase.call(propertyId);
});

final tenantByIdProvider = FutureProvider.family<Tenant?, String>((ref, id) {
  final useCase = ref.watch(getTenantByIdUseCaseProvider);
  return useCase.call(id);
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
      await _useCase.call(
        tenantId: tenantId,
        propertyId: propertyId,
        roomId: roomId,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Tenant removed and room marked as vacant',
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
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
