import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentFirestoreDataSource {
  final FirebaseFirestore _firestore;

  PaymentFirestoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getPaymentForLeaseMonth({
    required String leaseId,
    required int month,
    required int year,
  }) async {
    final snap = await _firestore
        .collection('payments')
        .where('leaseId', isEqualTo: leaseId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  Future<Map<String, dynamic>?> getOldestOpenPaymentForLease({
    required String leaseId,
  }) async {
    final snap = await _firestore
        .collection('payments')
        .where('leaseId', isEqualTo: leaseId)
        .limit(100)
        .get();

    if (snap.docs.isEmpty) return null;

    final openDocs = snap.docs.where((doc) {
      final data = doc.data();
      final status =
          (data['status']?.toString().trim().toLowerCase() ?? 'pending');
      return status != 'paid' && status != 'success';
    }).toList();

    if (openDocs.isEmpty) return null;

    int compareDocs(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b,
    ) {
      final aData = a.data();
      final bData = b.data();

      final aDue = _toDate(aData['dueDate']);
      final bDue = _toDate(bData['dueDate']);
      if (aDue != null && bDue != null) {
        return aDue.compareTo(bDue);
      }

      final aYear = _toInt(aData['year']);
      final bYear = _toInt(bData['year']);
      if (aYear != bYear) return aYear.compareTo(bYear);

      final aMonth = _toInt(aData['month']);
      final bMonth = _toInt(bData['month']);
      if (aMonth != bMonth) return aMonth.compareTo(bMonth);

      final aCreated = _toDate(aData['createdAt']);
      final bCreated = _toDate(bData['createdAt']);
      if (aCreated != null && bCreated != null) {
        return aCreated.compareTo(bCreated);
      }

      return a.id.compareTo(b.id);
    }

    openDocs.sort(compareDocs);
    final first = openDocs.first;
    return {'id': first.id, ...first.data()};
  }

  DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
