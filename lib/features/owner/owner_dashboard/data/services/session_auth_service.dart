import 'package:firebase_auth/firebase_auth.dart';

class SessionAuthService {
  final FirebaseAuth _auth;

  SessionAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  Future<void> signOut() {
    return _auth.signOut();
  }
}
