// features/owner/presentation/providers/dashboard_data_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';

class DashboardDataNotifier
    extends Notifier<AsyncValue<DashboardSummary>> {
  @override
  AsyncValue<DashboardSummary> build() {
    return const AsyncValue.loading();
  }

  void setLoading() {
    state = const AsyncValue.loading();
  }

  void setData(DashboardSummary summary) {
    state = AsyncValue.data(summary);
  }

  void setError(Object error, StackTrace stackTrace) {
    state = AsyncValue.error(error, stackTrace);
  }

  void reset() {
    state = AsyncValue.data(DashboardSummary.empty);
  }
}

final dashboardSummaryProvider =
    NotifierProvider<DashboardDataNotifier, AsyncValue<DashboardSummary>>(
  DashboardDataNotifier.new,
);