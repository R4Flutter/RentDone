import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class GetReportData {
  final ReportsRepository _repository;

  const GetReportData(this._repository);

  Future<ReportData> call({
    required bool isMonthly,
    required String year,
    required String property,
  }) {
    return _repository.getReportData(
      isMonthly: isMonthly,
      year: year,
      property: property,
    );
  }
}
