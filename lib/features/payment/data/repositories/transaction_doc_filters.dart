import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/payment/data/repositories/datetime_converter.dart';

class TransactionDocFilters {
  static bool matches(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int year,
    String? status,
  ) {
    final data = doc.data();
    if (year != 0) {
      final createdAt = DateTimeConverter.toDate(data['createdAt']);
      if (createdAt?.year != year) return false;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      return (data['status'] as String? ?? '').trim() == status;
    }
    return true;
  }

  static bool isAfterCursor(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    DateTime? startAfterCreatedAt,
    String? startAfterDocId,
  ) {
    if (startAfterCreatedAt == null || startAfterDocId == null) return true;
    final createdAt = DateTimeConverter.toDate(doc.data()['createdAt']);
    if (createdAt == null) return false;
    return createdAt.isBefore(startAfterCreatedAt) ||
        (createdAt.isAtSameMomentAs(startAfterCreatedAt) &&
            doc.id.compareTo(startAfterDocId) < 0);
  }
}
