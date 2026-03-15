import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';

class TenantRemindersStore {
  final FirebaseFirestore firestore;

  const TenantRemindersStore(this.firestore);

  Future<List<TenantReminder>> recent(String tenantId, {int limit = 5}) async {
    try {
      final snapshot = await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('reminders')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map(TenantReminder.fromFirestore).toList();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return const <TenantReminder>[];
      rethrow;
    }
  }
}
