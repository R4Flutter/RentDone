import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';

import 'tenant_payment_rate_metrics.dart';
import 'tenant_profile_metrics.dart';

class TenantDashboardMetrics {
  static ({double onTimeRate, double lateRate}) paymentRates({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs,
    required int dueDay,
    required int? onTimePayments,
    required int? latePayments,
  }) => TenantPaymentRateMetrics.resolve(
    paymentDocs: paymentDocs,
    dueDay: dueDay,
    onTimePayments: onTimePayments,
    latePayments: latePayments,
  );

  static double tenureYears(
    Map<String, dynamic> tenantData,
    TenantRoomDetails? roomDetails,
  ) => TenantProfileMetrics.tenureYears(tenantData, roomDetails);

  static String tenantPhone(
    Map<String, dynamic> tenantData,
    Map<String, dynamic> userData,
  ) => TenantProfileMetrics.tenantPhone(tenantData, userData);
}
