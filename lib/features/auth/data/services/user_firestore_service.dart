import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';

class UserFirestoreService {
  final _firestore = FirebaseFirestore.instance;

  /// Collection name
  static const String _usersCollection = 'users';

  /// ─────────────────────────────
  /// CREATE OR UPDATE USER
  /// ─────────────────────────────
  Future<void> createOrUpdateUser(AuthUser user) async {
    try {
      await _firestore.collection(_usersCollection).doc(user.uid).set({
        ...user.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to save user data: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// GET USER BY UID
  /// ─────────────────────────────
  Future<AuthUser?> getUserByUid(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (!doc.exists) {
        return null;
      }

      return AuthUser.fromMap({'uid': doc.id, ...doc.data() ?? {}});
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to fetch user data: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// UPDATE USER PROFILE
  /// ─────────────────────────────
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String role,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'name': name,
        'role': role,
        'isProfileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to update user profile: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// UPDATE LAST LOGIN
  /// ─────────────────────────────
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to update login time: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// DELETE USER
  /// ─────────────────────────────
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to delete user: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// STREAM USER DATA
  /// ─────────────────────────────
  Stream<AuthUser?> streamUser(String uid) {
    try {
      return _firestore.collection(_usersCollection).doc(uid).snapshots().map((
        doc,
      ) {
        if (!doc.exists) {
          return null;
        }
        return AuthUser.fromMap({'uid': doc.id, ...doc.data() ?? {}});
      });
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to stream user data: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// CHECK IF USER EXISTS
  /// ─────────────────────────────
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      return doc.exists;
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to check user existence: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// SEARCH USERS BY PHONE
  /// ─────────────────────────────
  Future<List<AuthUser>> searchUsersByPhone(String phone) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('phone', isEqualTo: phone)
          .get();

      return query.docs
          .map((doc) => AuthUser.fromMap({'uid': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to search users: ${e.toString()}',
      );
    }
  }

  /// ─────────────────────────────
  /// SEARCH USERS BY EMAIL
  /// ─────────────────────────────
  Future<List<AuthUser>> searchUsersByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .get();

      return query.docs
          .map((doc) => AuthUser.fromMap({'uid': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      throw UserFirestoreException(
        message: 'Failed to search users by email: ${e.toString()}',
      );
    }
  }
}

/// ─────────────────────────────
/// CUSTOM FIRESTORE EXCEPTION
/// ─────────────────────────────
class UserFirestoreException implements Exception {
  final String message;
  const UserFirestoreException({required this.message});

  @override
  String toString() => message;
}
