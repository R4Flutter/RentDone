class AddTenantState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  const AddTenantState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  AddTenantState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return AddTenantState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }
}