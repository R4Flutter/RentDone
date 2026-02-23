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

class OrphanTenantCleanupState {
  final bool isLoading;
  final int? cleanedCount;
  final String? errorMessage;

  const OrphanTenantCleanupState({
    this.isLoading = false,
    this.cleanedCount,
    this.errorMessage,
  });

  OrphanTenantCleanupState copyWith({
    bool? isLoading,
    int? cleanedCount,
    String? errorMessage,
  }) {
    return OrphanTenantCleanupState(
      isLoading: isLoading ?? this.isLoading,
      cleanedCount: cleanedCount,
      errorMessage: errorMessage,
    );
  }
}

class OrphanTenantCleanupNotifier extends Notifier<OrphanTenantCleanupState> {
  @override
  OrphanTenantCleanupState build() => const OrphanTenantCleanupState();

  Future<void> cleanup() async {
    state = const OrphanTenantCleanupState(isLoading: true);
    try {
      final count = await ref.read(cleanupOrphanTenantsUseCaseProvider)();
      state = OrphanTenantCleanupState(isLoading: false, cleanedCount: count);
    } catch (error) {
      state = OrphanTenantCleanupState(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  void clearResult() {
    state = const OrphanTenantCleanupState();
  }
}

final orphanTenantCleanupProvider =
    NotifierProvider<OrphanTenantCleanupNotifier, OrphanTenantCleanupState>(
      OrphanTenantCleanupNotifier.new,
    );
