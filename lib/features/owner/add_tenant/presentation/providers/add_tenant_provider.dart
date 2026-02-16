import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/add_tenant/domain/usecases/add_tenant_usecases.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/providers/add_tenant_di.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

import 'add_tenant_state.dart';

class AddTenantNotifier extends Notifier<AddTenantState> {
  late final AddTenantUseCase _useCase;

  @override
  AddTenantState build() {
    // Inject usecase from another provider
    _useCase = ref.read(addTenantUseCaseProvider);
    return const AddTenantState();
  }

  Future<void> submitTenant(Tenant tenant) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isSuccess: false,
    );

    try {
      await _useCase(tenant);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const AddTenantState();
  }
}

final addTenantNotifierProvider =
    NotifierProvider<AddTenantNotifier, AddTenantState>(AddTenantNotifier.new);
