import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/bottom_nav_bar_theme.dart';

// ── Design tokens (spec: RentDoneAnimatedBottomNavbar) ────────────────────────
const _kBarHeight = 59.0;
const _kIconRise = 16.0; // active icon lifts this many px above rest pos
const _kNotchRadius = 34.0;
const _kNotchDepth = 44.0;
const _kTopRadius = 28.0;
const _kTotalHeight = _kBarHeight + _kIconRise;

const _kActiveColor = Color(0xFF5DA8FF);
const _kInactiveColor = Color(0xFF5A6C8E);
const _kGlowColor = Color(0xFF3D8DFF);
const _kNavBgTop = Color(0xFF0A1F44);
const _kNavBgBottom = Color(0xFF081631);

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
    return SizedBox(
      height: _kTotalHeight,
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
                    height: _kBarHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(_kTopRadius),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 28,
                            offset: const Offset(0, -6),
                          ),
                          BoxShadow(
                            color: _kGlowColor.withValues(alpha: 0.14),
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
                    height: _kBarHeight,
                    child: ClipPath(
                      clipper: clipper,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_kNavBgTop, _kNavBgBottom],
                            ),
                            border: Border(
                              top: BorderSide(
                                color: _kGlowColor.withValues(alpha: 0.22),
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
                      padding: const EdgeInsets.only(top: _kIconRise),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NavIcon(
                              index: 0,
                              icon: Icons.dashboard_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onTap,
                            ),
                          ),
                          Expanded(
                            child: _NavIcon(
                              index: 1,
                              icon: Icons.person_add_alt_1_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onTap,
                            ),
                          ),
                          Expanded(
                            child: _NavIcon(
                              index: 2,
                              icon: Icons.add_business_rounded,
                              currentIndex: widget.currentIndex,
                              onTap: widget.onTap,
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

  const _NavIcon({
    required this.index,
    required this.icon,
    required this.currentIndex,
    required this.onTap,
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
                // Glow + opacity container
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? _kActiveColor.withValues(alpha: 0.22)
                        : Colors.transparent,
                    border: isActive
                        ? Border.all(
                            color: _kActiveColor.withValues(alpha: 0.45),
                            width: 1,
                          )
                        : null,
                  ),
                  child: AnimatedOpacity(
                    opacity: isActive ? 1.0 : 0.70,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      icon,
                      size: 24,
                      color: isActive
                          ? const Color(0xFFB7D7FF)
                          : _kInactiveColor,
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
