import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_data_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/alerts_panel.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_error.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_skeleton.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/header.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/messages_panel.dart';
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
            const HeaderSection()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.12, end: 0),
            const SizedBox(height: 24),

            StatsGrid(summary: summary),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (!isWide) {
                  return Column(
                    children: [
                      PaymentsOverview(summary: summary),
                      const SizedBox(height: 16),
                      const MessagesPanel(),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PaymentsOverview(summary: summary),
                          const SizedBox(height: 16),
                          const MessagesPanel(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    const Expanded(
                      flex: 2,
                      child: AlertsPanel(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
            const RecentActivity(),
          ],
        );
      },
    );
  }
}
