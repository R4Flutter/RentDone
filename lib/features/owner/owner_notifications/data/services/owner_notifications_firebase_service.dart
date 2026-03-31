import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_notifications/data/models/owner_notification_dto.dart';

class OwnerNotificationsFirebaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  OwnerNotificationsFirebaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  Stream<List<OwnerNotificationDto>> watchRecentNotifications({
    int limit = 12,
  }) {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<OwnerNotificationDto>>.empty();
    }

    return _firestore
        .collection('messages')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(OwnerNotificationDto.fromDoc).toList(),
        );
  }
}
