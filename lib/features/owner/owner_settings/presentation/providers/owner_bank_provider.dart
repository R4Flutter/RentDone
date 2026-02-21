import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_settings/data/services/owner_bank_firestore_service.dart';

class OwnerBankState {
  final bool isLoading;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String branch;
  final bool isVerified;
  final String? errorMessage;
  final String? successMessage;

  const OwnerBankState({
    this.isLoading = false,
    this.accountHolderName = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.branch = '',
    this.isVerified = false,
    this.errorMessage,
    this.successMessage,
  });

  OwnerBankState copyWith({
    bool? isLoading,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifsc,
    String? branch,
    bool? isVerified,
    String? errorMessage,
    String? successMessage,
  }) {
    return OwnerBankState(
      isLoading: isLoading ?? this.isLoading,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      branch: branch ?? this.branch,
      isVerified: isVerified ?? this.isVerified,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

final ownerBankFirestoreServiceProvider = Provider<OwnerBankFirestoreService>(
  (ref) => OwnerBankFirestoreService(),
);

class OwnerBankNotifier extends Notifier<OwnerBankState> {
  late final OwnerBankFirestoreService _service;
  late final FirebaseAuth _auth;

  @override
  OwnerBankState build() {
    _service = ref.read(ownerBankFirestoreServiceProvider);
    _auth = FirebaseAuth.instance;
    Future.microtask(load);
    return const OwnerBankState();
  }

  Future<void> load() async {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) {
      state = state.copyWith(
        errorMessage: 'Please login to set bank details.',
        successMessage: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _service.getOwnerBankProfile(ownerId);
      state = state.copyWith(
        isLoading: false,
        accountHolderName: profile?.accountHolderName ?? '',
        bankName: profile?.bankName ?? '',
        accountNumber: profile?.accountNumber ?? '',
        ifsc: profile?.ifsc ?? '',
        branch: profile?.branch ?? '',
        isVerified: profile?.isVerified ?? false,
        errorMessage: null,
        successMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load bank details.',
        successMessage: null,
      );
    }
  }

  void updateAccountHolderName(String value) =>
      state = state.copyWith(accountHolderName: value.trim());

  void updateBankName(String value) =>
      state = state.copyWith(bankName: value.trim());

  void updateAccountNumber(String value) =>
      state = state.copyWith(accountNumber: value.trim());

  void updateIfsc(String value) =>
      state = state.copyWith(ifsc: value.trim().toUpperCase());

  void updateBranch(String value) =>
      state = state.copyWith(branch: value.trim());

  Future<void> verifyAndSaveBankDetails() async {
    if (!_isValidAccountHolder(state.accountHolderName)) {
      state = state.copyWith(
        errorMessage: 'Enter the account holder name.',
        successMessage: null,
      );
      return;
    }
    if (state.bankName.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter the bank name.',
        successMessage: null,
      );
      return;
    }
    if (!_isValidAccountNumber(state.accountNumber)) {
      state = state.copyWith(
        errorMessage: 'Enter a valid account number.',
        successMessage: null,
      );
      return;
    }
    if (!_isValidIfsc(state.ifsc)) {
      state = state.copyWith(
        errorMessage: 'Enter a valid IFSC code.',
        successMessage: null,
      );
      return;
    }

    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) {
      state = state.copyWith(
        errorMessage: 'Please login to verify bank details.',
        successMessage: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _service.saveVerifiedBankDetails(
        ownerId: ownerId,
        accountHolderName: state.accountHolderName,
        bankName: state.bankName,
        accountNumber: state.accountNumber,
        ifsc: state.ifsc,
        branch: state.branch,
      );
      state = state.copyWith(
        isLoading: false,
        isVerified: true,
        errorMessage: null,
        successMessage: 'Bank details saved successfully.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to save bank details. Try again.',
        successMessage: null,
      );
    }
  }

  bool _isValidAccountHolder(String value) => value.trim().length >= 3;

  bool _isValidAccountNumber(String value) =>
      RegExp(r'^[0-9]{6,20}$').hasMatch(value.trim());

  bool _isValidIfsc(String value) =>
      RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value.trim());
}

final ownerBankProvider = NotifierProvider<OwnerBankNotifier, OwnerBankState>(
  OwnerBankNotifier.new,
);
