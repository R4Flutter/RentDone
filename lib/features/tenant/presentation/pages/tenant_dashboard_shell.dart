import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/bottom_nav_bar_theme.dart';

const _kTenantBarHeight = 62.0;
const _kTenantIconRise = 16.0;
const _kTenantNotchRadius = 38.0;
const _kTenantNotchDepth = 42.0;
const _kTenantTopRadius = 30.0;
const _kTenantSideInset = 24.0;
const _kTenantTotalHeight = _kTenantBarHeight + _kTenantIconRise;

double _tenantLerp(double a, double b, double t) => a + (b - a) * t;

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
    if (location.contains('/tenant/payments')) return 1;
    if (location.contains('/tenant/transactions')) return 1;
    if (location.contains('/tenant/documents')) return 2;
    if (location.contains('/tenant/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
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
                  color: Color.lerp(
                    OwnerDashboardColors.brandPrimary(context),
                    AppColors.white,
                    0.24,
                  )!,
                ),
              ),
              Positioned(
                bottom: -110,
                right: -30,
                child: _LiquidBlob(
                  size: 260,
                  color: Color.lerp(
                    OwnerDashboardColors.brandPrimaryHover(context),
                    AppColors.black,
                    0.10,
                  )!,
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
                onSelected: (index) {
                  switch (index) {
                    case 0:
                      context.go('/tenant/dashboard');
                      break;
                    case 1:
                      context.go('/tenant/payments');
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

class _TenantBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _TenantBottomNavBar({
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  State<_TenantBottomNavBar> createState() => _TenantBottomNavBarState();
}

class _TenantBottomNavBarState extends State<_TenantBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1.0;
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _TenantBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  double _xOf(int index, double width) {
    final available = (width - (_kTenantSideInset * 2)).clamp(120.0, width);
    final slot = available / 4;
    return _kTenantSideInset + (slot * index) + (slot / 2);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final navBase = isDark ? AppColors.cFF020617 : AppColors.cFFFFFFFF;
    final borderColor = isDark
        ? AppColors.white.withValues(alpha: 0.14)
        : AppColors.black.withValues(alpha: 0.08);

    return SizedBox(
      height: _kTenantTotalHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final notchX = _tenantLerp(
                _xOf(_previousIndex, width),
                _xOf(widget.currentIndex, width),
                _animation.value,
              );

              final clipper = BarWithNotchClipper(
                notchCenterX: notchX,
                notchRadius: _kTenantNotchRadius,
                notchDepth: _kTenantNotchDepth,
                topRadius: _kTenantTopRadius,
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: _kTenantBarHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(_kTenantTopRadius),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(
                              alpha: isDark ? 0.45 : 0.14,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, -6),
                          ),
                          BoxShadow(
                            color: brand.withValues(
                              alpha: isDark ? 0.16 : 0.09,
                            ),
                            blurRadius: 36,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: _kTenantBarHeight,
                    child: ClipPath(
                      clipper: clipper,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                navBase.withValues(alpha: isDark ? 0.75 : 0.88),
                                brand.withValues(alpha: isDark ? 0.15 : 0.08),
                              ],
                            ),
                            border: Border(
                              top: BorderSide(color: borderColor, width: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: _kTenantIconRise,
                        left: _kTenantSideInset,
                        right: _kTenantSideInset,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TenantNavIcon(
                              index: 0,
                              icon: Icons.dashboard_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onSelected,
                              activeColor: OwnerDashboardColors.navActive(
                                context,
                              ),
                              inactiveColor: OwnerDashboardColors.navInactive(
                                context,
                              ),
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _TenantNavIcon(
                              index: 1,
                              icon: Icons.receipt_long_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onSelected,
                              activeColor: OwnerDashboardColors.navActive(
                                context,
                              ),
                              inactiveColor: OwnerDashboardColors.navInactive(
                                context,
                              ),
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _TenantNavIcon(
                              index: 2,
                              icon: Icons.lock_outline_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onSelected,
                              activeColor: OwnerDashboardColors.navActive(
                                context,
                              ),
                              inactiveColor: OwnerDashboardColors.navInactive(
                                context,
                              ),
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _TenantNavIcon(
                              index: 3,
                              icon: Icons.person_outline_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onSelected,
                              activeColor: OwnerDashboardColors.navActive(
                                context,
                              ),
                              inactiveColor: OwnerDashboardColors.navInactive(
                                context,
                              ),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TenantNavIcon extends StatelessWidget {
  final int index;
  final IconData icon;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;

  const _TenantNavIcon({
    required this.index,
    required this.icon,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isActive ? -_kTenantIconRise : 0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, dy, _) => Transform.translate(
            offset: Offset(0, dy),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isActive ? 1.15 : 0.95),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, scale, _) => Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              activeColor.withValues(alpha: 0.25),
                              activeColor.withValues(alpha: 0.12),
                            ],
                          )
                        : null,
                    border: isActive
                        ? Border.all(
                            color: activeColor.withValues(
                              alpha: isDark ? 0.5 : 0.4,
                            ),
                            width: 1.2,
                          )
                        : Border.all(color: Colors.transparent, width: 1.2),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedOpacity(
                    opacity: isActive ? 1.0 : 0.65,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      icon,
                      size: 24,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                ),
              ),
            ),
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
