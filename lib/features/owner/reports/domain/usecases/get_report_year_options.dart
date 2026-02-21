import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class GetReportYearOptions {
  final ReportsRepository _repository;

  const GetReportYearOptions(this._repository);

  Future<List<String>> call() {
    return _repository.getYearOptions();
  }
}
