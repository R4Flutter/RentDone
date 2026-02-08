import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/presentation/pages/navigation_bar.dart';
import 'package:rentdone/features/owner/presentation/pages/owner_page_drawer.dart';
import 'package:rentdone/features/owner/presentation/providers/dashboard_layout_provider.dart';
import 'package:rentdone/features/owner/presentation/widgets/dashboard/dashboard_body.dart';



class OwnerDashboardPage extends ConsumerWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(dashboardLayoutProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Row(
          children: [
            /// 🧭 SIDEBAR
            if (isDesktop || ui.isSidebarOpen)
              const OwnerSideDrawer(),

            /// 🧠 MAIN CONTENT
            Expanded(
              child: Column(
                children: const [
                  OwnerTopNavBar(),
                  Expanded(child: DashboardBody()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}