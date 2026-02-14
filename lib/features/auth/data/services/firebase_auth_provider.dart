import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_firebase_services.dart';

/// FirebaseAuth instance provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// AuthFirebaseService provider
final authFirebaseServiceProvider = Provider<AuthFirebaseService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AuthFirebaseService(auth);
});

/// Stream of current user authentication state
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// Is user authenticated
final isAuthenticatedProvider = StreamProvider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => Stream.value(user != null),
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});
