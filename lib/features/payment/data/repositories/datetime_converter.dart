import 'package:cloud_firestore/cloud_firestore.dart';

class DateTimeConverter {
  static DateTime? toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
