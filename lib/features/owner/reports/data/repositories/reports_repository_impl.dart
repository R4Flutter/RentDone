import 'package:rentdone/features/owner/reports/data/services/reports_local_service.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsLocalService _service;

  ReportsRepositoryImpl(this._service);

  @override
  Future<List<String>> getYearOptions() {
    return _service.getYearOptions();
  }

  @override
  Future<List<String>> getPropertyOptions() {
    return _service.getPropertyOptions();
  }

  @override
  Future<ReportData> getReportData({
    required bool isMonthly,
    required String year,
    required String property,
  }) async {
    final dto = await _service.getReportData(
      isMonthly: isMonthly,
      year: year,
      property: property,
    );
    return dto.toEntity();
  }
}
