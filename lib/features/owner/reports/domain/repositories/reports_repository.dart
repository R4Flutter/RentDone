import 'package:rentdone/features/owner/reports/domain/entities/report_filter.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';

abstract class ReportsRepository {
  Future<List<int>> getYearOptions();

  Future<List<ReportPropertyOption>> getPropertyOptions();

  Future<ReportData> getReportData({
    required ReportFilter filter,
    String? propertyId,
  });

  Future<String> exportReport({
    required String format,
    required ReportData data,
    required ReportFilter filter,
    String? propertyId,
  });
}
