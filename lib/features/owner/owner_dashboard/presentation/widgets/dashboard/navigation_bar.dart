import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_layout_provider.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/user_menu.dart';

class OwnerTopNavBar extends ConsumerStatefulWidget {
  const OwnerTopNavBar({super.key});

  static const _height = 64.0;
  static const _sideSlotWidth = 60.0;

  @override
  ConsumerState<OwnerTopNavBar> createState() => _OwnerTopNavBarState();
}

class _OwnerTopNavBarState extends ConsumerState<OwnerTopNavBar> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = OwnerDashboardColors.isDark(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final navBase = isDark ? AppColors.cFF020617 : AppColors.cFFFFFFFF;
    final menuColor = OwnerDashboardColors.iconPrimary(context);
    final brandColor = isDark ? AppColors.cFFF8FAFC : AppColors.cFF0F172A;

    return Material(
      color: AppColors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: OwnerTopNavBar._height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  navBase.withValues(alpha: isDark ? 0.82 : 0.9),
                  OwnerDashboardColors.brandPrimary(
                    context,
                  ).withValues(alpha: isDark ? 0.1 : 0.06),
                ],
              ),
              border: Border(
                bottom: BorderSide(color: OwnerDashboardColors.border(context)),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  top: -20,
                  child: IgnorePointer(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            OwnerDashboardColors.brandPrimary(
                              context,
                            ).withValues(alpha: isDark ? 0.14 : 0.1),
                            AppColors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/rentdone_logo.png',
                            height: 50,
                            width: 50,
                            fit: BoxFit.contain,
                          ),
                          Text(
                            'RentDone',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              letterSpacing: 0.3,
                              color: brandColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: OwnerTopNavBar._sideSlotWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _MenuTapScale(
                            onTap: () {
                              if (isDesktop) {
                                ref
                                    .read(dashboardLayoutProvider.notifier)
                                    .toggleSidebar();
                                return;
                              }
                              final scaffold = Scaffold.maybeOf(context);
                              if (scaffold != null && scaffold.hasDrawer) {
                                scaffold.openDrawer();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.menu_rounded,
                                size: 24,
                                color: menuColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: OwnerTopNavBar._sideSlotWidth,
                        child: const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: UserMenu(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTapScale extends StatefulWidget {
  const _MenuTapScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_MenuTapScale> createState() => _MenuTapScaleState();
}

class _MenuTapScaleState extends State<_MenuTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
