import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    SidebarItem('Settings', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currentIndex = _calculateIndex(context);

    return Material(
      color: scheme.surface, // 60%
      elevation: 0,
      child: SizedBox(
        width: _sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileHeader(),

            Divider(height: 1, color: scheme.onSurface.withValues(alpha: 0.08)),

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
                      onTap: () {
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
                            context.goNamed('ownerSettings');
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
    if (location.contains('/owner/settings')) return 6;

    return 0;
  }
}
