import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class AuthStateNotifier extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? currentUser;
  Map<String, dynamic>? userData;
  UserRole? role;
  bool isProfileComplete = false;
  bool isLoading = true;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  AuthStateNotifier(this._auth, this._firestore) {
    _authSub = _auth.authStateChanges().listen((user) {
      currentUser = user;
      _userDocSub?.cancel();

      if (user != null) {
        _userDocSub = _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
          if (snapshot.exists) {
            userData = snapshot.data();
            role = UserRoleX.tryParse(userData?['role'] as String?);
            
            final phone = (userData?['phone'] as String? ?? '').trim();
            final name = (userData?['name'] as String? ?? '').trim();
            isProfileComplete = phone.isNotEmpty && name.isNotEmpty;
          } else {
            userData = null;
            role = null;
            isProfileComplete = false;
          }
          isLoading = false;
          notifyListeners();
        }, onError: (e) {
          debugPrint('Router AuthState error: $e');
          isLoading = false;
          notifyListeners();
        });
      } else {
        userData = null;
        role = null;
        isProfileComplete = false;
        isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}

final authRouterStateProvider = Provider<AuthStateNotifier>((ref) {
  return AuthStateNotifier(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});
