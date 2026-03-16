import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/reports/data/repositories/reports_repository_impl.dart';
import 'package:rentdone/features/owner/reports/data/services/reports_firebase_service.dart';
import 'package:rentdone/features/owner/reports/domain/repositories/reports_repository.dart';
import 'package:rentdone/features/owner/reports/domain/usecases/export_report.dart';
import 'package:rentdone/features/owner/reports/domain/usecases/get_report_data.dart';
import 'package:rentdone/features/owner/reports/domain/usecases/get_report_property_options.dart';
import 'package:rentdone/features/owner/reports/domain/usecases/get_report_year_options.dart';

final reportsFirebaseServiceProvider = Provider<ReportsFirebaseService>((ref) {
  return ReportsFirebaseService();
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final service = ref.watch(reportsFirebaseServiceProvider);
  return ReportsRepositoryImpl(service);
});

final getReportDataUseCaseProvider = Provider<GetReportData>((ref) {
  return GetReportData(ref.watch(reportsRepositoryProvider));
});

final getReportYearOptionsUseCaseProvider = Provider<GetReportYearOptions>((
  ref,
) {
  return GetReportYearOptions(ref.watch(reportsRepositoryProvider));
});

final getReportPropertyOptionsUseCaseProvider =
    Provider<GetReportPropertyOptions>((ref) {
      return GetReportPropertyOptions(ref.watch(reportsRepositoryProvider));
    });

final exportReportUseCaseProvider = Provider<ExportReport>((ref) {
  return ExportReport(ref.watch(reportsRepositoryProvider));
});
