import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_layout_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/sidebar_item.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/profile_header.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/drive_style.dart';

class OwnerSideDrawer extends ConsumerWidget {
  const OwnerSideDrawer({super.key});

  static const double _sidebarWidth = 280;

  static final List<SidebarItem> items = [
    SidebarItem('Profile', Icons.person_outline_rounded),
    SidebarItem('Properties', Icons.apartment_rounded),
    SidebarItem('Manage Tenants', Icons.people_alt_rounded),
    SidebarItem('Payments', Icons.account_balance_wallet_rounded),
    SidebarItem('Bank Details', Icons.account_balance_outlined),
    SidebarItem('Reports', Icons.bar_chart_rounded),
    SidebarItem('Subscription', Icons.workspace_premium),
    SidebarItem('Tenant Trust Score', Icons.verified_user),
    SidebarItem('Settings', Icons.settings_rounded),
    SidebarItem('Logout', Icons.logout_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final panelColor =
        Color.lerp(scheme.surface, AppColors.white, isDark ? 0.02 : 0.3) ??
        scheme.surface;
    final currentIndex = _calculateIndex(context);

    return Material(
      color: AppColors.transparent,
      elevation: 0,
      child: SizedBox(
        width: _sidebarWidth,
        child: Container(
          decoration: BoxDecoration(
            color: panelColor,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.3 : 0.14),
                blurRadius: 22,
                offset: const Offset(10, 10),
              ),
              BoxShadow(
                color: AppColors.white.withValues(alpha: isDark ? 0.04 : 0.75),
                blurRadius: 20,
                offset: const Offset(-8, -8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileHeader(),

              Divider(
                height: 1,
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = index == currentIndex;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: DriveStyleTile(
                        item: item,
                        selected: selected,
                        onTap: () async {
                          final isDesktop =
                              MediaQuery.of(context).size.width >= 1024;

                          ref
                              .read(dashboardLayoutProvider.notifier)
                              .onItemSelected(index, isDesktop);

                          switch (index) {
                            case 0:
                              context.goNamed('ownerProfile');
                              break;
                            case 1:
                              context.goNamed('ownerProperties');
                              break;
                            case 2:
                              context.goNamed('manageTenants');
                              break;
                            case 3:
                              context.goNamed('ownerPayments');
                              break;
                            case 4:
                              context.goNamed('ownerBankDetails');
                              break;
                            case 5:
                              context.goNamed('ownerReports');
                              break;
                            case 6:
                              context.goNamed('ownerSubscription');
                              break;
                            case 7:
                              context.goNamed('ownerTrustScore');
                              break;
                            case 8:
                              context.goNamed('ownerSettings');
                              break;
                          case 9:
                            // BUG-03 fix: use the repository signOut which also
                            // calls googleSignIn.signOut() to clear the Google session.
                            // BUG-04 fix: redirect to /role, not /login?role=owner.
                            await ref.read(authRepositoryProvider).signOut();
                            if (context.mounted) {
                              context.go('/role');
                            }
                            break;
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    if (location.contains('/owner/profile')) return 0;
    if (location.contains('/owner/properties')) return 1;
    if (location.contains('/owner/tenants')) return 2;
    if (location.contains('/owner/payments')) return 3;
    if (location.contains('/owner/bank-details')) return 4;
    if (location.contains('/owner/reports')) return 5;
    if (location.contains('/owner/subscription')) return 6;
    if (location.contains('/owner/trust-score')) return 7;
    if (location.contains('/owner/settings')) return 8;

    return 0;
  }
}
