import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';
import 'package:rentdone/features/auth/domain/repositories/auth_repository.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';

class _FakeAuthRepository implements AuthRepository {
  AuthUser? registerResult;
  AuthUser? signInResult;
  AuthUser? googleResult;
  Object? registerError;
  Object? signInError;
  Object? googleError;

  int registerCalls = 0;
  int signInCalls = 0;
  int googleCalls = 0;

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  }) async {
    registerCalls++;
    if (registerError != null) {
      throw registerError!;
    }
    return registerResult ??
        const AuthUser(uid: 'reg-1', role: 'owner', isProfileComplete: true);
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  }) async {
    signInCalls++;
    if (signInError != null) {
      throw signInError!;
    }
    return signInResult ??
        const AuthUser(uid: 'sign-1', role: 'owner', isProfileComplete: true);
  }

  @override
  Future<AuthUser> signInWithGoogle({
    required UserRole selectedRole,
    required String phone,
  }) async {
    googleCalls++;
    if (googleError != null) {
      throw googleError!;
    }
    return googleResult ??
        const AuthUser(uid: 'google-1', role: 'tenant', isProfileComplete: true);
  }

  @override
  Future<void> sendOtp({required String phone}) async {}

  @override
  Future<AuthUser> verifyOtp({required String otp}) async {
    return const AuthUser(uid: 'otp-1');
  }

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<UserRole?> getUserRole(String uid) async => null;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> sendPasswordResetCode({String? email}) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  ProviderContainer containerWithRepo(_FakeAuthRepository fakeRepo) {
    return ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  }

  test('continueWithEmail uses register flow in register mode', () async {
    final fakeRepo = _FakeAuthRepository();
    final container = containerWithRepo(fakeRepo);
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    notifier.setSelectedRole(UserRole.owner);
    notifier.setMode(registerMode: true);

    await notifier.continueWithEmail(
      email: 'owner@example.com',
      password: 'strongpass',
      phone: '9876543210',
    );

    expect(fakeRepo.registerCalls, 1);
    expect(fakeRepo.signInCalls, 0);
  });

  test('continueWithEmail uses sign-in flow in login mode', () async {
    final fakeRepo = _FakeAuthRepository();
    final container = containerWithRepo(fakeRepo);
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    notifier.setSelectedRole(UserRole.owner);
    notifier.setMode(registerMode: false);

    await notifier.continueWithEmail(
      email: 'owner@example.com',
      password: 'strongpass',
      phone: '9876543210',
    );

    expect(fakeRepo.signInCalls, 1);
    expect(fakeRepo.registerCalls, 0);
  });

  test('continueWithEmail rejects invalid phone number', () async {
    final fakeRepo = _FakeAuthRepository();
    final container = containerWithRepo(fakeRepo);
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    notifier.setSelectedRole(UserRole.owner);

    await expectLater(
      () => notifier.continueWithEmail(
        email: 'owner@example.com',
        password: 'strongpass',
        phone: '1234567890',
      ),
      throwsA(isA<StateError>()),
    );

    final state = container.read(authProvider);
    expect(state.errorMessage, 'Enter a valid phone number.');
  });

  test('continueWithGoogle surfaces repository error message', () async {
    final fakeRepo = _FakeAuthRepository()..googleError = Exception('boom');
    final container = containerWithRepo(fakeRepo);
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    notifier.setSelectedRole(UserRole.tenant);

    await expectLater(
      () => notifier.continueWithGoogle(phone: '9876543210'),
      throwsA(isA<Exception>()),
    );

    final state = container.read(authProvider);
    expect(state.errorMessage, 'boom');
  });
}
