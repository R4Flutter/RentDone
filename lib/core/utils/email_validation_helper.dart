import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Helper class for email validation and duplicate detection
class EmailValidationHelper {
  final FirebaseFirestore _firestore;

  EmailValidationHelper({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Checks if an email is already registered in the system
  /// Returns the UID of the existing user if found, null otherwise
  Future<String?> findUserWithEmail(String email) async {
    if (email.trim().isEmpty) return null;

    final normalizedEmail = email.trim().toLowerCase();

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('emailLowercase', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return querySnapshot.docs.first.id;
    } catch (e) {
      debugPrint('Error checking email: $e');
      return null;
    }
  }

  /// Checks if an email can be used by a specific user
  /// Returns true if the email is available or already belongs to this user
  Future<bool> canUserUseEmail(String email, String userId) async {
    final existingUserId = await findUserWithEmail(email);

    // Email is available if no one uses it, or if the current user uses it
    return existingUserId == null || existingUserId == userId;
  }

  /// Finds all duplicate emails in the users collection
  /// Returns a map of email -> list of user IDs
  Future<Map<String, List<String>>> findDuplicateEmails() async {
    final duplicates = <String, List<String>>{};

    try {
      final snapshot = await _firestore.collection('users').get();

      final emailToUsers = <String, List<String>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final email = data['emailLowercase'] as String?;

        if (email != null && email.isNotEmpty) {
          emailToUsers.putIfAbsent(email, () => []).add(doc.id);
        }
      }

      // Filter to only duplicates
      for (final entry in emailToUsers.entries) {
        if (entry.value.length > 1) {
          duplicates[entry.key] = entry.value;
        }
      }

      return duplicates;
    } catch (e) {
      debugPrint('Error finding duplicates: $e');
      return {};
    }
  }

  /// Validates email format
  static bool isValidEmailFormat(String email) {
    if (email.trim().isEmpty) return false;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return emailRegex.hasMatch(email.trim());
  }

  /// Normalizes an email address (trim and lowercase)
  static String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }
}
