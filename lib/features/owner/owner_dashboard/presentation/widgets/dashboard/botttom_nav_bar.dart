import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/bottom_nav_bar_theme.dart';

class PinterestMorphNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const PinterestMorphNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final backgroundColor = isDark ? AppTheme.nearBlack : AppTheme.pureWhite;

    return SizedBox(
      height: 85,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          /// 🔵 Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.blueSurfaceGradient,
            ),
          ),

          /// 🕳️ Hollow Cut Shape
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 85),
            painter: NavPainter(
              index: currentIndex,
              backgroundColor: backgroundColor,
            ),
          ),

          /// 🔘 Icons
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
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 55,
        width: 55,
        decoration: isSelected
            ? BoxDecoration(shape: BoxShape.circle, color: scheme.surface)
            : null,
        child: Icon(
          icon,
          size: 26,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
