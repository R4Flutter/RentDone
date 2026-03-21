import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/di/dashboard_di.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';

final dashboardSummaryProvider = StreamProvider<DashboardSummary>((ref) {
  final useCase = ref.watch(watchDashboardSummaryUseCaseProvider);
  return useCase();
});
