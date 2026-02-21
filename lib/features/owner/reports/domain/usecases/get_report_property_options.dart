import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';

class GetReportPropertyOptions {
  final ReportsRepository _repository;

  const GetReportPropertyOptions(this._repository);

  Future<List<String>> call() {
    return _repository.getPropertyOptions();
  }
}
