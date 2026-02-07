import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import 'sidebar_item.dart';

class OwnerSidebar extends ConsumerWidget {
  const OwnerSidebar({super.key});

  static final items = [
    SidebarItem('Dashboard', Icons.home_outlined),
    SidebarItem('Properties', Icons.apartment_outlined),
    SidebarItem('Tenants', Icons.people_outline),
    SidebarItem('Payments', Icons.account_balance_wallet_outlined),
    SidebarItem('Reports', Icons.bar_chart_outlined),
    SidebarItem('Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(dashboardProvider);

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        children: [
          // LOGO
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: const [
                CircleAvatar(
                  backgroundColor: Color(0xFF2563EB),
                  child: Icon(Icons.home, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text(
                  'RentApp',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // MENU
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, index) {
                final item = items[index];
                final selected = index == selectedIndex;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: selected
                        ? const Color(0xFFEFF6FF)
                        : Colors.transparent,
                    leading: Icon(
                      item.icon,
                      color:
                          selected ? const Color(0xFF2563EB) : Colors.black54,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? const Color(0xFF2563EB)
                            : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      ref.read(dashboardProvider.notifier).setIndex(index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}