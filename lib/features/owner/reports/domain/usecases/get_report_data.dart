import 'package:rentdone/features/owner/reports/domain/entities/report_filter.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class GetReportData {
  final ReportsRepository _repository;

  const GetReportData(this._repository);

  Future<ReportData> call({required ReportFilter filter, String? propertyId}) {
    return _repository.getReportData(filter: filter, propertyId: propertyId);
  }
}
