import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_di.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  final useCase = ref.watch(getDashboardSummaryUseCaseProvider);
  return useCase();
});
