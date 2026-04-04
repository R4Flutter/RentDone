import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rentdone/firebase/firebase_options.dart';

Future<void> _configureEmulatorsIfEnabled() async {
  const host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  const useAuthEmulator = bool.fromEnvironment(
    'USE_AUTH_EMULATOR',
    defaultValue: false,
  );
  const useFirestoreEmulator = bool.fromEnvironment(
    'USE_FIRESTORE_EMULATOR',
    defaultValue: false,
  );

  const authPort = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  const firestorePort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );

  if (useAuthEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
  }
  if (useFirestoreEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _configureEmulatorsIfEnabled();
  });

  testWidgets('auth emulator signup and signin smoke', (tester) async {
    const useAuthEmulator = bool.fromEnvironment(
      'USE_AUTH_EMULATOR',
      defaultValue: false,
    );
    const useFirestoreEmulator = bool.fromEnvironment(
      'USE_FIRESTORE_EMULATOR',
      defaultValue: false,
    );

    if (!useAuthEmulator || !useFirestoreEmulator) {
      // Keep test green by default; enforce in CI/local with emulator flags.
      expect(true, isTrue);
      return;
    }

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final unique = DateTime.now().microsecondsSinceEpoch;
    final email = 'it_auth_$unique@example.com';
    const password = 'strongpass123';

    UserCredential? created;
    try {
      created = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = created.user;
      expect(user, isNotNull);

      if (user != null) {
        await firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'emailLowercase': email.toLowerCase(),
          'role': 'owner',
          'phone': '9876543210',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await auth.signOut();
      await auth.signInWithEmailAndPassword(email: email, password: password);
      expect(auth.currentUser?.email, email);
    } finally {
      final uid = created?.user?.uid;
      if (uid != null && uid.isNotEmpty) {
        await firestore.collection('users').doc(uid).delete();
      }
      await auth.currentUser?.delete();
      await auth.signOut();
    }
  });
}
