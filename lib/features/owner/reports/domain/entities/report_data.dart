class ReportPropertyOption {
  const ReportPropertyOption({required this.id, required this.name});

  final String id;
  final String name;
}

class MonthlySummary {
  const MonthlySummary({
    required this.expected,
    required this.collected,
    required this.pending,
    required this.collectionRate,
  });

  final int expected;
  final int collected;
  final int pending;
  final double collectionRate;
}

class PropertyIncomeReport {
  const PropertyIncomeReport({
    required this.propertyId,
    required this.propertyName,
    required this.expected,
    required this.collected,
    required this.pending,
  });

  final String propertyId;
  final String propertyName;
  final int expected;
  final int collected;
  final int pending;
}

class TenantPaymentStatusReport {
  const TenantPaymentStatusReport({
    required this.tenantId,
    required this.tenantName,
    required this.roomNumber,
    required this.propertyName,
    required this.monthlyRent,
    required this.status,
  });

  final String tenantId;
  final String tenantName;
  final String roomNumber;
  final String propertyName;
  final int monthlyRent;
  final String status;
}

class OverdueTenantReport {
  const OverdueTenantReport({
    required this.tenantId,
    required this.tenantName,
    required this.roomNumber,
    required this.pendingAmount,
    required this.daysLate,
  });

  final String tenantId;
  final String tenantName;
  final String roomNumber;
  final int pendingAmount;
  final int daysLate;
}

class MonthlyCollectionPoint {
  const MonthlyCollectionPoint({required this.label, required this.amount});

  final String label;
  final int amount;
}

class PaymentMethodBreakdown {
  const PaymentMethodBreakdown({required this.method, required this.amount});

  final String method;
  final int amount;
}

class VacancyReport {
  const VacancyReport({
    required this.totalRooms,
    required this.occupiedRooms,
    required this.vacantRooms,
  });

  final int totalRooms;
  final int occupiedRooms;
  final int vacantRooms;
}

class TopPayingTenantReport {
  const TopPayingTenantReport({
    required this.tenantId,
    required this.tenantName,
    required this.propertyName,
    required this.totalPaid,
  });

  final String tenantId;
  final String tenantName;
  final String propertyName;
  final int totalPaid;
}

class ReportData {
  const ReportData({
    required this.monthlySummary,
    required this.propertyIncome,
    required this.tenantStatuses,
    required this.overdueTenants,
    required this.monthlyTrend,
    required this.paymentMethodBreakdown,
    required this.yearlyEarnings,
    required this.vacancyReport,
    required this.topPayingTenants,
  });

  final MonthlySummary monthlySummary;
  final List<PropertyIncomeReport> propertyIncome;
  final List<TenantPaymentStatusReport> tenantStatuses;
  final List<OverdueTenantReport> overdueTenants;
  final List<MonthlyCollectionPoint> monthlyTrend;
  final List<PaymentMethodBreakdown> paymentMethodBreakdown;
  final int yearlyEarnings;
  final VacancyReport vacancyReport;
  final List<TopPayingTenantReport> topPayingTenants;
}
