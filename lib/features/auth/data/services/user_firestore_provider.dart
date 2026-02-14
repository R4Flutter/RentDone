import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_firestore_service.dart';

/// UserFirestoreService provider
final userFirestoreServiceProvider = Provider<UserFirestoreService>((ref) {
  return UserFirestoreService();
});
