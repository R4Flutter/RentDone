import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class GetReportPropertyOptions {
  final ReportsRepository _repository;

  const GetReportPropertyOptions(this._repository);

  Future<List<ReportPropertyOption>> call() {
    return _repository.getPropertyOptions();
  }
}
