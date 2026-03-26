import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class TenantDashboardShell extends ConsumerStatefulWidget {
  final Widget child;

  const TenantDashboardShell({super.key, required this.child});

  @override
  ConsumerState<TenantDashboardShell> createState() =>
      _TenantDashboardShellState();
}

class _TenantDashboardShellState extends ConsumerState<TenantDashboardShell> {
  bool _isDashboardLocation(String location) {
    return location.startsWith('/tenant/dashboard');
  }

  int _calculateIndex(String location) {
    if (location.contains('/tenant/transactions')) return 1;
    if (location.contains('/tenant/documents')) return 2;
    if (location.contains('/tenant/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final location = GoRouterState.of(context).uri.toString();
    final isDashboard = _isDashboardLocation(location);

    return PopScope(
      canPop: isDashboard,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final currentLocation = GoRouterState.of(context).uri.toString();
        if (!_isDashboardLocation(currentLocation)) {
          context.go('/tenant/dashboard');
        }
      },
      child: Scaffold(
        backgroundColor: OwnerDashboardColors.pageBackground(context),
        extendBody: true,
        drawer: _TenantSideDrawer(currentLocation: location),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                      context,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -80,
                left: -50,
                child: _LiquidBlob(
                  size: 220,
                  color: OwnerDashboardColors.ownerTopBlobColor(context),
                ),
              ),
              Positioned(
                bottom: -110,
                right: -30,
                child: _LiquidBlob(
                  size: 260,
                  color: OwnerDashboardColors.ownerBottomBlobColor(context),
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: AppColors.transparent),
              ),
              Positioned.fill(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    scaffoldBackgroundColor: AppColors.transparent,
                    canvasColor: AppColors.transparent,
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: isDesktop
            ? null
            : _TenantBottomNavBar(
                currentIndex: _calculateIndex(location),
                avatarUrl: user?.photoURL,
                onSelected: (index) {
                  switch (index) {
                    case 0:
                      context.go('/tenant/dashboard');
                      break;
                    case 1:
                      context.go('/tenant/transactions');
                      break;
                    case 2:
                      context.go('/tenant/documents');
                      break;
                    case 3:
                      context.go('/tenant/profile');
                      break;
                  }
                },
              ),
      ),
    );
  }
}

class _TenantBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String? avatarUrl;
  final ValueChanged<int> onSelected;

  const _TenantBottomNavBar({
    required this.currentIndex,
    required this.avatarUrl,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final navBase = isDark ? AppColors.cFF020617 : AppColors.cFFFFFFFF;
    final borderColor = isDark
        ? AppColors.white.withValues(alpha: 0.14)
        : AppColors.black.withValues(alpha: 0.08);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    navBase.withValues(alpha: isDark ? 0.84 : 0.92),
                    brand.withValues(alpha: isDark ? 0.14 : 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(
                      alpha: isDark ? 0.22 : 0.10,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: brand.withValues(alpha: isDark ? 0.12 : 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TenantNavItem(
                      icon: Icons.home_outlined,
                      label: 'Home',
                      selected: currentIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                  ),
                  Expanded(
                    child: _TenantNavItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Payments',
                      selected: currentIndex == 1,
                      onTap: () => onSelected(1),
                    ),
                  ),
                  Expanded(
                    child: _TenantNavItem(
                      icon: Icons.wallet_outlined,
                      label: 'Vault',
                      selected: currentIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                  ),
                  Expanded(
                    child: _TenantProfileNavItem(
                      selected: currentIndex == 3,
                      avatarUrl: avatarUrl,
                      onTap: () => onSelected(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TenantNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = OwnerDashboardColors.navActive(context);
    final inactive = OwnerDashboardColors.navInactive(context);
    final isDark = OwnerDashboardColors.isDark(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    active.withValues(alpha: isDark ? 0.22 : 0.14),
                    active.withValues(alpha: isDark ? 0.10 : 0.06),
                  ],
                )
              : null,
          border: Border.all(
            color: selected
                ? active.withValues(alpha: isDark ? 0.34 : 0.18)
                : AppColors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? active : inactive),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? active : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantProfileNavItem extends StatelessWidget {
  final bool selected;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _TenantProfileNavItem({
    required this.selected,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = OwnerDashboardColors.navActive(context);
    final inactive = OwnerDashboardColors.navInactive(context);
    final isDark = OwnerDashboardColors.isDark(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    active.withValues(alpha: isDark ? 0.22 : 0.14),
                    active.withValues(alpha: isDark ? 0.10 : 0.06),
                  ],
                )
              : null,
          border: Border.all(
            color: selected
                ? active.withValues(alpha: isDark ? 0.34 : 0.18)
                : AppColors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: selected
                  ? active
                  : inactive.withValues(alpha: isDark ? 0.24 : 0.18),
              backgroundImage: (avatarUrl ?? '').isNotEmpty
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: (avatarUrl ?? '').isEmpty
                  ? Icon(
                      Icons.person,
                      size: 12,
                      color: selected ? AppColors.white : inactive,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              'Profile',
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? active : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantSideDrawer extends StatelessWidget {
  final String currentLocation;

  const _TenantSideDrawer({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final baseColor = OwnerDashboardColors.cardBackground(context);
    final panelColor =
        Color.lerp(baseColor, AppColors.white, isDark ? 0.02 : 0.28) ??
        baseColor;

    return Drawer(
      width: 300,
      backgroundColor: panelColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: OwnerDashboardColors.brandPrimary(
                        context,
                      ).withValues(alpha: isDark ? 0.18 : 0.10),
                    ),
                    child: Icon(
                      Icons.dashboard_customize_rounded,
                      color: OwnerDashboardColors.brandPrimary(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenant Menu',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'White, blue, black dashboard system',
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Divider(color: OwnerDashboardColors.border(context)),
              const SizedBox(height: 16),
              _DrawerItem(
                icon: Icons.map_outlined,
                label: 'Explore Map',
                subtitle: 'Search properties by city',
                selected: currentLocation.startsWith('/tenant/city'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/city');
                },
              ),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.report_problem_outlined,
                label: 'Complaints',
                subtitle: 'Submit & track issues',
                selected: currentLocation.startsWith('/tenant/complaints'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/complaints');
                },
              ),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.lock_outline_rounded,
                label: 'Document Vault',
                subtitle: 'Secure file storage',
                selected: currentLocation.startsWith('/tenant/documents'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/documents');
                },
              ),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.receipt_long_rounded,
                label: 'Payments',
                subtitle: 'History & dues',
                selected: currentLocation.startsWith('/tenant/transactions'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/transactions');
                },
              ),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                subtitle: 'Account details',
                selected: currentLocation.startsWith('/tenant/profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/profile');
                },
              ),
              const Spacer(),
              Divider(color: OwnerDashboardColors.border(context)),
              const SizedBox(height: 8),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                subtitle: 'App preferences',
                selected: false,
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final baseColor = OwnerDashboardColors.elevatedBackground(context);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      brand.withValues(alpha: isDark ? 0.18 : 0.10),
                      brand.withValues(alpha: isDark ? 0.08 : 0.04),
                    ],
                  )
                : null,
            color: selected ? null : baseColor.withValues(alpha: 0.92),
            border: Border.all(
              color: selected
                  ? brand.withValues(alpha: isDark ? 0.30 : 0.16)
                  : OwnerDashboardColors.border(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: brand.withValues(alpha: isDark ? 0.18 : 0.10),
                ),
                child: Icon(icon, color: brand, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: selected ? brand : textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _LiquidBlob({required this.size, required this.color});

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
