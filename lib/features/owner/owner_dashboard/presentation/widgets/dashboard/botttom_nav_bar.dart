import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/bottom_nav_bar_theme.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';

// ── Design tokens (spec: RentDoneAnimatedBottomNavbar) ────────────────────────
const _kBarHeight = 59.0;
const _kIconRise = 16.0; // active icon lifts this many px above rest pos
const _kNotchRadius = 34.0;
const _kNotchDepth = 38.0;
const _kTopRadius = 28.0;
const _kTotalHeight = _kBarHeight + _kIconRise;

double _lerpd(double a, double b, double t) => a + (b - a) * t;

// ── Main widget ───────────────────────────────────────────────────────────────

class PinterestMorphNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const PinterestMorphNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<PinterestMorphNavBar> createState() => _PinterestMorphNavBarState();
}

class _PinterestMorphNavBarState extends State<PinterestMorphNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _anim;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1.0;
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void didUpdateWidget(PinterestMorphNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _prevIndex = old.currentIndex;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // Icon center X for a given index in a bar of [width].
  static double _xOf(int index, double width) => width / 3 * index + width / 6;

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final navBase = isDark ? AppColors.cFF020617 : AppColors.cFFFFFFFF;
    final activeColor = OwnerDashboardColors.navActive(context);
    final inactiveColor = OwnerDashboardColors.navInactive(context);
    final hideTopBorderForProperties = widget.currentIndex == 2;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _kTotalHeight + bottomPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              // Notch X slides between icon positions.
              final notchX = _lerpd(
                _xOf(_prevIndex, width),
                _xOf(widget.currentIndex, width),
                _anim.value,
              );

              final clipper = BarWithNotchClipper(
                notchCenterX: notchX,
                notchRadius: _kNotchRadius,
                notchDepth: _kNotchDepth,
                topRadius: _kTopRadius,
              );

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Drop shadow (outside ClipPath so it shows everywhere) ─
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: _kBarHeight + bottomPadding,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(_kTopRadius),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
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

                  // ── Glass bar with animated notch cutout ───────────────
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: _kBarHeight + bottomPadding,
                    child: ClipPath(
                      clipper: clipper,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: GlassmorphismConfig.strongBlurAmount,
                          sigmaY: GlassmorphismConfig.strongBlurAmount,
                        ),
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
                              top: BorderSide(
                                color: hideTopBorderForProperties
                                    ? AppColors.transparent
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : Colors.black.withValues(
                                              alpha: 0.1,
                                            )),
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Icons (full height, padded into bar area) ──────────
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(top: _kIconRise, bottom: bottomPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavIcon(
                              index: 0,
                              icon: Icons.dashboard_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onTap,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _NavIcon(
                              index: 1,
                              icon: Icons.person_add_alt_1_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onTap,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              isDark: isDark,
                            ),
                          ),
                          Expanded(
                            child: _NavIcon(
                              index: 2,
                              icon: Icons.add_business_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onTap,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
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

// ── _NavIcon ──────────────────────────────────────────────────────────────────

class _NavIcon extends StatelessWidget {
  final int index;
  final IconData icon;
  final int currentIndex;
  final Function(int) onTap;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;

  const _NavIcon({
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
        // Vertical lift animation (spring-like easeOutBack)
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: isActive ? -_kIconRise : 0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, dy, _) => Transform.translate(
            offset: Offset(0, dy),
            // Scale animation
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isActive ? 1.15 : 0.95),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, scale, _) => Transform.scale(
                scale: scale,
                // Glassmorphic container for icon
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
