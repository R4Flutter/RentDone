import 'package:cloud_firestore/cloud_firestore.dart';

class TenantTrust {
  const TenantTrust({
    required this.trustScore,
    required this.latePayments,
    required this.totalPayments,
    required this.propertiesStayed,
    required this.complaints,
    required this.onTimeRate,
    required this.lastUpdated,
  });

  final int trustScore;
  final int latePayments;
  final int totalPayments;
  final int propertiesStayed;
  final int complaints;
  final int onTimeRate;
  final DateTime? lastUpdated;

  String get paymentReliability {
    if (onTimeRate >= 95) return 'Excellent';
    if (onTimeRate >= 85) return 'Good';
    if (onTimeRate >= 70) return 'Average';
    return 'Needs Attention';
  }

  factory TenantTrust.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return TenantTrust(
      trustScore: ((data['trustScore'] as num?)?.toInt() ?? 0).clamp(0, 100),
      latePayments: (data['latePayments'] as num?)?.toInt() ?? 0,
      totalPayments: (data['totalPayments'] as num?)?.toInt() ?? 0,
      propertiesStayed: (data['propertiesStayed'] as num?)?.toInt() ?? 0,
      complaints: (data['complaints'] as num?)?.toInt() ?? 0,
      onTimeRate: ((data['onTimeRate'] as num?)?.toInt() ?? 0).clamp(0, 100),
      lastUpdated: parseDate(data['lastUpdated']),
    );
  }
}
