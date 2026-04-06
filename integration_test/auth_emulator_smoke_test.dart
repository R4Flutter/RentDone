import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/data/services/auth_firebase_services.dart';
import 'package:rentdone/firebase/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late AuthFirebaseService service;

  Future<void> signOutIfNeeded() async {
    if (auth.currentUser != null) {
      await auth.signOut();
    }
  }

  Future<void> cleanupUserDoc(String uid) async {
    try {
      await firestore.collection('users').doc(uid).delete();
    } catch (_) {
      // Best-effort cleanup in emulator test environment.
    }
  }

  Future<void> cleanupCurrentAuthUser() async {
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } catch (_) {
      // Ignore if delete fails due to emulator state.
    }
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;

    const useAuthEmulator = bool.fromEnvironment(
      'USE_AUTH_EMULATOR',
      defaultValue: false,
    );
    const useFirestoreEmulator = bool.fromEnvironment(
      'USE_FIRESTORE_EMULATOR',
      defaultValue: false,
    );

    if (!useAuthEmulator || !useFirestoreEmulator) {
      throw StateError(
        'Auth smoke test must run against emulators only. '
        'Pass --dart-define=USE_AUTH_EMULATOR=true '
        'and --dart-define=USE_FIRESTORE_EMULATOR=true.',
      );
    }

    const emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    const authPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
    const firestorePort = int.fromEnvironment(
      'FIRESTORE_EMULATOR_PORT',
      defaultValue: 8080,
    );

    auth.useAuthEmulator(emulatorHost, authPort);
    firestore.useFirestoreEmulator(emulatorHost, firestorePort);

    service = AuthFirebaseService(auth, firestore, GoogleSignIn.instance);
  });

  tearDown(() async {
    await signOutIfNeeded();
  });

  testWidgets('tenant signup writes expected user profile fields', (_) async {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final email = 'tenant+$seed@rentdone.test';
    const password = 'TenantPass#1234';

    final created = await service.registerWithEmail(
      email: email,
      password: password,
      selectedRole: UserRole.tenant,
      phone: '9876543210',
    );

    expect(created.uid.isNotEmpty, isTrue);
    expect(created.role, UserRole.tenant.value);

    final userDoc = await firestore.collection('users').doc(created.uid).get();
    final data = userDoc.data();

    expect(userDoc.exists, isTrue);
    expect(data, isNotNull);
    expect(data!['uid'], created.uid);
    expect(data['role'], UserRole.tenant.value);
    expect(data['emailLowercase'], email.toLowerCase());
    expect((data['phone'] as String?)?.isNotEmpty ?? false, isTrue);

    await cleanupUserDoc(created.uid);
    await cleanupCurrentAuthUser();
  });

  testWidgets('owner self-signup is rejected by auth service hardening', (_) async {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final email = 'owner+$seed@rentdone.test';

    expect(
      () => service.registerWithEmail(
        email: email,
        password: 'OwnerPass#1234',
        selectedRole: UserRole.owner,
        phone: '9876543210',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('register as tenants'),
        ),
      ),
    );
  });

  testWidgets('tenant sign-in works and invalid password fails', (_) async {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final email = 'signin+$seed@rentdone.test';
    const password = 'ValidPass#1234';

    final created = await service.registerWithEmail(
      email: email,
      password: password,
      selectedRole: UserRole.tenant,
      phone: '9876543210',
    );

    await auth.signOut();

    final signedIn = await service.signInWithEmail(
      email: email,
      password: password,
      selectedRole: UserRole.tenant,
      phone: '9876543210',
    );

    expect(signedIn.uid, created.uid);

    await auth.signOut();

    expect(
      () => service.signInWithEmail(
        email: email,
        password: 'WrongPass#9999',
        selectedRole: UserRole.tenant,
        phone: '9876543210',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Invalid email or password'),
        ),
      ),
    );

    // Re-authenticate for cleanup delete() requirements.
    await service.signInWithEmail(
      email: email,
      password: password,
      selectedRole: UserRole.tenant,
      phone: '9876543210',
    );

    await cleanupUserDoc(created.uid);
    await cleanupCurrentAuthUser();
  });
}
