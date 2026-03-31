import 'package:rentdone/features/owner/reports/data/services/reports_firebase_service.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_filter.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsFirebaseService _service;

  ReportsRepositoryImpl(this._service);

  @override
  Future<List<int>> getYearOptions() {
    return _service.getYearOptions();
  }

  @override
  Future<List<ReportPropertyOption>> getPropertyOptions() {
    return _service.getPropertyOptions();
  }

  @override
  Future<ReportData> getReportData({
    required ReportFilter filter,
    String? propertyId,
  }) {
    return _service.getReportData(
      filter: filter,
      propertyId: propertyId,
    );
  }

  @override
  Future<String> exportReport({
    required String format,
    required ReportData data,
    required ReportFilter filter,
    String? propertyId,
  }) {
    return _service.exportReport(
      format: format,
      data: data,
      filter: filter,
      propertyId: propertyId,
    );
  }
}
