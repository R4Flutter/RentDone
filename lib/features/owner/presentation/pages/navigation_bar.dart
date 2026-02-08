import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/presentation/providers/dashboard_layout_provider.dart';
import 'package:rentdone/features/owner/presentation/widgets/dashboard/user_menu.dart';


class OwnerTopNavBar extends ConsumerWidget {
  const OwnerTopNavBar({super.key});

  static const _height = 64.0;
  static const _borderColor = Color(0xFFE5E7EB);
  static const _primaryColor = Color(0xFF6D28D9);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _borderColor),
          ),
        ),
        child: Row(
          children: [
            /// ☰ LEFT – HAMBURGER
            IconButton(
              tooltip: 'Toggle sidebar',
              icon: const Icon(Icons.menu),
              onPressed: () {
                ref
                    .read(dashboardLayoutProvider.notifier)
                    .toggleSidebar();
              },
            ),

            /// CENTER – LOGO + APP NAME
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _primaryColor,
                      child: Icon(
                        Icons.home_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'RentApp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// RIGHT – USER / ACCOUNT (BEST FOR RENT APP)
            UserMenu(),
          ],
        ),
      ),
    );
  }
}