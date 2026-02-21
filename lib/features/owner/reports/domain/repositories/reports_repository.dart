import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';

abstract class ReportsRepository {
  Future<List<String>> getYearOptions();

  Future<List<String>> getPropertyOptions();

  Future<ReportData> getReportData({
    required bool isMonthly,
    required String year,
    required String property,
  });
}
