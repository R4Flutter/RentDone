import 'package:cloud_firestore/cloud_firestore.dart';

class TenantRoomDetails {
  final String propertyName;
  final String roomNumber;
  final int monthlyRent;
  final int? depositAmount;
  final DateTime allocationDate;
  final int rentDueDay;

  const TenantRoomDetails({
    required this.propertyName,
    required this.roomNumber,
    required this.monthlyRent,
    required this.depositAmount,
    required this.allocationDate,
    required this.rentDueDay,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'propertyName': propertyName,
      'roomNumber': roomNumber,
      'monthlyRent': monthlyRent,
      if (depositAmount != null) 'depositAmount': depositAmount,
      'allocationDate': Timestamp.fromDate(allocationDate),
      'rentDueDay': rentDueDay,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TenantRoomDetails.fromMap(Map<String, dynamic> map) {
    final allocationRaw = map['allocationDate'];
    DateTime allocationDate;
    if (allocationRaw is Timestamp) {
      allocationDate = allocationRaw.toDate();
    } else if (allocationRaw is DateTime) {
      allocationDate = allocationRaw;
    } else {
      allocationDate = DateTime.now();
    }

    return TenantRoomDetails(
      propertyName: (map['propertyName'] as String? ?? '').trim(),
      roomNumber: (map['roomNumber'] as String? ?? '').trim(),
      monthlyRent: (map['monthlyRent'] as num?)?.toInt() ?? 0,
      depositAmount: (map['depositAmount'] as num?)?.toInt(),
      allocationDate: allocationDate,
      rentDueDay: (map['rentDueDay'] as num?)?.toInt() ?? 1,
    );
  }
}
