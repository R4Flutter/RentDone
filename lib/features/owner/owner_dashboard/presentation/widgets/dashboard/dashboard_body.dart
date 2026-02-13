import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_data_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/alerts_panel.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_error.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_skeleton.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/header.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/payment_overview.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/recent_activity.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/stat_grid.dart';

class DashboardnewBody extends ConsumerWidget {
  const DashboardnewBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardSummaryProvider);

    return dashboardAsync.when(
      loading: () => const DashboardSkeleton(),
      error: (e, _) => const DashboardError(),
      data: (summary) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const HeaderSection(),
            const SizedBox(height: 24),

            StatsGrid(summary: summary),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: PaymentsOverview(summary: summary),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  flex: 2,
                  child: AlertsPanel(),
                ),
              ],
            ),

            const SizedBox(height: 32),
            const RecentActivity(),
          ],
        );
      },
    );
  }
}