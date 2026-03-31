class AppConfig {
  final bool paymentsEnabled;
  final bool manualPaymentsEnabled;
  final bool razorpayEnabled;
  final bool maintenanceMode;
  final DateTime? lastUpdatedAt;

  const AppConfig({
    required this.paymentsEnabled,
    required this.manualPaymentsEnabled,
    required this.razorpayEnabled,
    required this.maintenanceMode,
    this.lastUpdatedAt,
  });

  factory AppConfig.defaults() {
    return const AppConfig(
      paymentsEnabled: true,
      manualPaymentsEnabled: true,
      razorpayEnabled: true,
      maintenanceMode: false,
    );
  }

  factory AppConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return AppConfig.defaults();
    return AppConfig(
      paymentsEnabled: data['paymentsEnabled'] != false,
      manualPaymentsEnabled: data['manualPaymentsEnabled'] != false,
      razorpayEnabled: data['razorpayEnabled'] != false,
      maintenanceMode: data['maintenanceMode'] == true,
      lastUpdatedAt: _parseTimestamp(data['lastUpdatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentsEnabled': paymentsEnabled,
      'manualPaymentsEnabled': manualPaymentsEnabled,
      'razorpayEnabled': razorpayEnabled,
      'maintenanceMode': maintenanceMode,
      'lastUpdatedAt': lastUpdatedAt?.toUtc().toIso8601String(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return null;
  }
}
