import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/bottom_nav_bar_theme.dart';

class PinterestMorphNavBar extends StatelessWidget {
  static const double _barHeight = 60;

  final int currentIndex;
  final Function(int) onTap;

  const PinterestMorphNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final backgroundColor = OwnerDashboardColors.cardBackground(context);

    return SizedBox(
      height: _barHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      backgroundColor.withValues(alpha: isDark ? 0.74 : 0.86),
                      OwnerDashboardColors.brandPrimary(
                        context,
                      ).withValues(alpha: isDark ? 0.12 : 0.08),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, -2),
                    ),
                    BoxShadow(
                      color: AppColors.white.withValues(
                        alpha: isDark ? 0.03 : 0.72,
                      ),
                      blurRadius: 16,
                      offset: const Offset(-6, -8),
                    ),
                    BoxShadow(
                      color: OwnerDashboardColors.brandPrimary(
                        context,
                      ).withValues(alpha: isDark ? 0.16 : 0.1),
                      blurRadius: 28,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -22,
            right: -8,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    OwnerDashboardColors.brandPrimary(
                      context,
                    ).withValues(alpha: isDark ? 0.2 : 0.14),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),

          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, _barHeight),
            painter: NavPainter(
              index: currentIndex,
              backgroundColor: backgroundColor,
            ),
          ),

          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _icon(context, Icons.dashboard_rounded, 0),
                _icon(context, Icons.person_add_alt_1_rounded, 1),
                _icon(context, Icons.add_business_rounded, 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(BuildContext context, IconData icon, int index) {
    final isSelected = currentIndex == index;
    final inactive = OwnerDashboardColors.navInactive(context);
    final primary = OwnerDashboardColors.navActive(context);

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 46,
        width: 46,
        decoration: isSelected
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(3, 5),
                  ),
                  BoxShadow(
                    color: AppColors.white.withValues(alpha: 0.62),
                    blurRadius: 8,
                    offset: const Offset(-3, -3),
                  ),
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              )
            : null,
        child: Icon(icon, size: 22, color: isSelected ? primary : inactive),
      ),
    );
  }
}
