import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/botttom_nav_bar.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/navigation_bar.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/owner_page_drawer.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/mobile_drawer.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_layout_provider.dart';
import 'package:rentdone/app/app_theme.dart';
import 'dart:ui';

class OwnerDashboardPage extends ConsumerWidget {
  const OwnerDashboardPage({super.key, required this.child});

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
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      extendBody: true, // IMPORTANT for curved nav
      drawer: isDesktop ? null : const OwnerMobileDrawer(),
      onDrawerChanged: (isOpen) {
        ref.read(dashboardLayoutProvider.notifier).setSidebarOpen(isOpen);
      },
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      OwnerDashboardColors.pageBackground(context),
                      Color.lerp(
                            OwnerDashboardColors.pageBackground(context),
                            OwnerDashboardColors.brandPrimary(context),
                            0.06,
                          ) ??
                          OwnerDashboardColors.pageBackground(context),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -50,
              child: _LiquidBlob(
                size: 220,
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -30,
              child: _LiquidBlob(
                size: 260,
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.12),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: AppColors.transparent),
            ),
            Row(
              children: [
                /// 🧭 SIDEBAR (Desktop Only)
                if (isDesktop) const OwnerSideDrawer(),

                /// 🧠 MAIN CONTENT
                Expanded(
                  child: Column(
                    children: [
                      const OwnerTopNavBar(),

                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
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

class _LiquidBlob extends StatelessWidget {
  const _LiquidBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, AppColors.transparent]),
      ),
    );
  }
}
