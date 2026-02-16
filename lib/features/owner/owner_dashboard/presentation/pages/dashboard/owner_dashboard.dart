import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/botttom_nav_bar.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/navigation_bar.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/owner_page_drawer.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/mobile_drawer.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_layout_provider.dart';

class OwnerDashboardPage extends ConsumerWidget {
  const OwnerDashboardPage({
    super.key,
    required this.child,
  });

  /// 🔥 This comes from ShellRoute
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    int calculateIndex(BuildContext context) {
      final location = GoRouterState.of(context).uri.toString();

      if (location.contains('/owner/tenants/add')) return 1;
      if (location.contains('/owner/properties')) return 2;

      return 0;
    }

    return Scaffold(
      backgroundColor: AppTheme.pureWhite,
      extendBody: true, // IMPORTANT for curved nav
      drawer: isDesktop ? null : const OwnerMobileDrawer(),
      onDrawerChanged: (isOpen) {
        ref.read(dashboardLayoutProvider.notifier).setSidebarOpen(isOpen);
      },
      body: SafeArea(
        child: Row(
          children: [
            /// 🧭 SIDEBAR (Desktop Only)
            if (isDesktop) const OwnerSideDrawer(),

            /// 🧠 MAIN CONTENT
            Expanded(
              child: Column(
                children: [
                  const OwnerTopNavBar(),

                  Expanded(
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      /// 🔥 MOBILE BOTTOM NAV ONLY
      bottomNavigationBar: isDesktop
          ? null
          : PinterestMorphNavBar(
              currentIndex: calculateIndex(context),
              onTap: (index) {
                switch (index) {
                  case 0:
                    context.go('/owner/dashboard');
                    break;
                  case 1:
                    context.go('/owner/tenants/add');
                    break;
                  case 2:
                    context.go('/owner/properties');
                    break;
                }
              },
            ),
    );
  }
}
