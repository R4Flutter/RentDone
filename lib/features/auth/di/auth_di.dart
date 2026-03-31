import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rentdone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:rentdone/features/auth/data/services/auth_firebase_services.dart';
import 'package:rentdone/features/auth/domain/repositories/auth_repository.dart';
import 'package:rentdone/features/auth/domain/usecases/get_current_user.dart';
import 'package:rentdone/features/auth/domain/usecases/send_otp.dart';
import 'package:rentdone/features/auth/domain/usecases/sign_out.dart';
import 'package:rentdone/features/auth/domain/usecases/verify_otp.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

final authFirebaseServiceProvider = Provider<AuthFirebaseService>((ref) {
  return AuthFirebaseService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(googleSignInProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authFirebaseServiceProvider));
});

final sendOtpUseCaseProvider = Provider<SendOtp>((ref) {
  return SendOtp(ref.watch(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider<VerifyOtp>((ref) {
  return VerifyOtp(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUser>((ref) {
  return GetCurrentUser(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOut>((ref) {
  return SignOut(ref.watch(authRepositoryProvider));
});
