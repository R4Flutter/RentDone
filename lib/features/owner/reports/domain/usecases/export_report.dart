import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_filter.dart';
import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class ExportReport {
  ExportReport(this._repository);

  final ReportsRepository _repository;

  Future<String> call({
    required String format,
    required ReportData data,
    required ReportFilter filter,
    String? propertyId,
  }) {
    return _repository.exportReport(
      format: format,
      data: data,
      filter: filter,
      propertyId: propertyId,
    );
  }
}
