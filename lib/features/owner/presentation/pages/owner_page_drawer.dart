import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/presentation/providers/dashboard_layout_provider.dart';
import 'package:rentdone/features/owner/presentation/ui_models/sidebar_item.dart';
import 'package:rentdone/features/owner/presentation/widgets/dashboard/profile_header.dart';
import 'package:rentdone/features/owner/presentation/widgets/dashboard/drive_style.dart';

class OwnerSideDrawer extends ConsumerWidget {
  const OwnerSideDrawer({super.key});

  static const double _sidebarWidth = 280;

  // Drive-like purple
  static const _dividerColor = Color(0xFFE5E7EB);

  static final List<SidebarItem> items = [
    SidebarItem('Dashboard', Icons.grid_view_rounded),
    SidebarItem('Properties', Icons.apartment_rounded),
    SidebarItem('Tenants', Icons.people_alt_rounded),
    SidebarItem('Payments', Icons.account_balance_wallet_rounded),
    SidebarItem('Reports', Icons.bar_chart_rounded),
    SidebarItem('Settings', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardLayoutProvider);

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: _sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileHeader(),

            const Divider(color: _dividerColor, height: 1),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index];
                  final selected = index == state.index;

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
}
