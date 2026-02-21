class AddTenantState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;
  final List<String> documentUrls;

  const AddTenantState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
    this.documentUrls = const [],
  });

  AddTenantState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    List<String>? documentUrls,
  }) {
    return AddTenantState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
      documentUrls: documentUrls ?? this.documentUrls,
    );
  }
}
