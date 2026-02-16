import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool useGradient;
  final Gradient? gradient;
  final Color? backgroundColor;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.useGradient = true,
    this.gradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final baseColor = scheme.surface;
    final resolvedGradient =
        gradient ?? (useGradient ? AppTheme.blueSurfaceGradient : null);
    final resolvedColor =
        resolvedGradient == null ? (backgroundColor ?? baseColor) : null;

    final shadowDark = Colors.black.withValues(alpha: isDark ? 0.5 : 0.18);
    final shadowLift = Colors.black.withValues(alpha: isDark ? 0.32 : 0.08);
    final shadowLight = Colors.white.withValues(alpha: isDark ? 0.06 : 0.55);
    final borderColor = Colors.white.withValues(alpha: isDark ? 0.1 : 0.14);

    return Container(
      decoration: BoxDecoration(
        color: resolvedColor,
        gradient: resolvedGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowDark,
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: shadowLift,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: shadowLight,
            blurRadius: 16,
            offset: const Offset(-6, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (resolvedGradient != null)
              Positioned(
                top: -40,
                left: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: -60,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                    colors: [
                      Colors.black.withValues(alpha: isDark ? 0.12 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
