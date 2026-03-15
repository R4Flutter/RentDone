import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';

class TenantProfileMetrics {
  static double tenureYears(
    Map<String, dynamic> tenantData,
    TenantRoomDetails? roomDetails,
  ) {
    final baseline =
        roomDetails?.allocationDate ??
        (tenantData['moveInDate'] as Timestamp?)?.toDate() ??
        (tenantData['leaseStartDate'] as Timestamp?)?.toDate() ??
        (tenantData['createdAt'] as Timestamp?)?.toDate();
    final totalDays = baseline == null
        ? 0
        : DateTime.now().difference(baseline).inDays;
    return totalDays <= 0
        ? 0
        : double.parse((totalDays / 365).toStringAsFixed(1));
  }

  static String tenantPhone(
    Map<String, dynamic> tenantData,
    Map<String, dynamic> userData,
  ) {
    final values = [
      tenantData['phoneNumber'],
      tenantData['phone'],
      tenantData['mobile'],
      userData['phoneNumber'],
      userData['phone'],
      userData['mobile'],
    ];
    for (final value in values) {
      final normalized = (value as String? ?? '').trim();
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }
}
