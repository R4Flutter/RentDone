enum ReportFilterType {
  thisMonth,
  thisYear,
  custom,
}

class ReportFilter {
  const ReportFilter({
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  final ReportFilterType type;
  final DateTime startDate;
  final DateTime endDate;

  static ReportFilter thisMonth({DateTime? now}) {
    final date = now ?? DateTime.now();
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    return ReportFilter(
      type: ReportFilterType.thisMonth,
      startDate: start,
      endDate: end,
    );
  }

  static ReportFilter thisYear({DateTime? now}) {
    final date = now ?? DateTime.now();
    final start = DateTime(date.year, 1, 1);
    final end = DateTime(date.year, 12, 31, 23, 59, 59);
    return ReportFilter(
      type: ReportFilterType.thisYear,
      startDate: start,
      endDate: end,
    );
  }

  ReportFilter copyWith({
    ReportFilterType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ReportFilter(
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}
