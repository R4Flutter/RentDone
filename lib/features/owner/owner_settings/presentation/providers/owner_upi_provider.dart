import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_settings/data/services/owner_upi_firestore_service.dart';

class OwnerUpiState {
  final bool isLoading;
  final String upiId;
  final bool isVerified;
  final String? errorMessage;
  final String? successMessage;

  const OwnerUpiState({
    this.isLoading = false,
    this.upiId = '',
    this.isVerified = false,
    this.errorMessage,
    this.successMessage,
  });

  OwnerUpiState copyWith({
    bool? isLoading,
    String? upiId,
    bool? isVerified,
    String? errorMessage,
    String? successMessage,
  }) {
    return OwnerUpiState(
      isLoading: isLoading ?? this.isLoading,
      upiId: upiId ?? this.upiId,
      isVerified: isVerified ?? this.isVerified,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

final ownerUpiFirestoreServiceProvider = Provider<OwnerUpiFirestoreService>((
  ref,
) {
  return OwnerUpiFirestoreService();
});

class OwnerUpiNotifier extends Notifier<OwnerUpiState> {
  late final OwnerUpiFirestoreService _service;
  late final FirebaseAuth _auth;

  @override
  OwnerUpiState build() {
    _service = ref.read(ownerUpiFirestoreServiceProvider);
    _auth = FirebaseAuth.instance;
    Future.microtask(load);
    return const OwnerUpiState();
  }

  Future<void> load() async {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) {
      state = state.copyWith(
        errorMessage: 'Please login to set UPI.',
        successMessage: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      final profile = await _service.getOwnerUpiProfile(ownerId);
      state = state.copyWith(
        isLoading: false,
        upiId: profile?.upiId ?? '',
        isVerified: profile?.isVerified ?? false,
        errorMessage: null,
        successMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load UPI settings.',
        successMessage: null,
      );
    }
  }

  void updateUpiId(String value) {
    state = state.copyWith(
      upiId: value.trim(),
      errorMessage: null,
      successMessage: null,
    );
  }

  Future<void> verifyAndSaveUpi() async {
    if (state.isVerified) {
      state = state.copyWith(
        errorMessage: 'UPI is already verified. Contact support to change it.',
        successMessage: null,
      );
      return;
    }

    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) {
      state = state.copyWith(
        errorMessage: 'Please login to verify UPI.',
        successMessage: null,
      );
      return;
    }

    if (!_isValidUpi(state.upiId)) {
      state = state.copyWith(
        errorMessage: 'Enter a valid UPI ID (example@bank).',
        successMessage: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      await _service.saveVerifiedUpi(ownerId: ownerId, upiId: state.upiId);
      state = state.copyWith(
        isLoading: false,
        isVerified: true,
        errorMessage: null,
        successMessage: 'UPI verified and saved.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'UPI verification failed. Try again.',
        successMessage: null,
      );
    }
  }

  Future<String?> getVerifiedUpiId() async {
    if (state.isVerified && state.upiId.isNotEmpty) {
      return state.upiId;
    }

    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null) return null;

    try {
      final profile = await _service.getOwnerUpiProfile(ownerId);
      if (profile == null || !profile.isVerified || profile.upiId.isEmpty) {
        return null;
      }

      state = state.copyWith(
        upiId: profile.upiId,
        isVerified: true,
        errorMessage: null,
        successMessage: null,
      );

      return profile.upiId;
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Unable to verify owner UPI right now.',
        successMessage: null,
      );
      return null;
    }
  }

  bool _isValidUpi(String value) {
    final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$');
    return upiRegex.hasMatch(value.trim());
  }
}

final ownerUpiProvider = NotifierProvider<OwnerUpiNotifier, OwnerUpiState>(
  OwnerUpiNotifier.new,
);
