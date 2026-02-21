import 'package:firebase_auth/firebase_auth.dart';

class OwnerProfileAuthService {
  final FirebaseAuth _auth;

  OwnerProfileAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
