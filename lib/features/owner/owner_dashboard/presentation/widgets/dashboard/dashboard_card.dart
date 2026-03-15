import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:rentdone/app/app_theme.dart';

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool useGradient;
  final Gradient? gradient;
  final Color? backgroundColor;
  final bool inset;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.useGradient = false,
    this.gradient,
    this.backgroundColor,
    this.inset = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final baseColor = OwnerDashboardColors.cardBackground(context);

    final resolvedGradient =
        gradient ??
        (useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(baseColor, AppColors.white, isDark ? 0.02 : 0.2) ??
                      baseColor,
                  Color.lerp(
                        baseColor,
                        OwnerDashboardColors.brandPrimary(context),
                        isDark ? 0.08 : 0.06,
                      ) ??
                      baseColor,
                ],
              )
            : null);

    final resolvedColor = resolvedGradient == null
        ? (backgroundColor ??
              (Color.lerp(baseColor, AppColors.white, isDark ? 0.03 : 0.1) ??
                  baseColor))
        : null;

    final shadowDark = AppColors.black.withValues(alpha: isDark ? 0.34 : 0.12);
    final shadowLight = AppColors.white.withValues(alpha: isDark ? 0.06 : 0.82);
    final liquidTint = OwnerDashboardColors.brandPrimary(
      context,
    ).withValues(alpha: isDark ? 0.12 : 0.07);
    final shellColor =
        resolvedColor ??
        Color.lerp(baseColor, AppColors.white, isDark ? 0.08 : 0.22)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: shellColor.withValues(alpha: isDark ? 0.76 : 0.86),
            gradient: resolvedGradient,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color:
                  Color.lerp(
                    OwnerDashboardColors.border(context),
                    liquidTint,
                    0.4,
                  ) ??
                  OwnerDashboardColors.border(context),
            ),
            boxShadow: [
              if (inset)
                BoxShadow(
                  color: shadowDark,
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(4, 4),
                  blurStyle: BlurStyle.inner,
                ),
              if (inset)
                BoxShadow(
                  color: shadowLight,
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(-4, -4),
                  blurStyle: BlurStyle.inner,
                ),
              if (!inset)
                BoxShadow(
                  color: shadowDark,
                  blurRadius: 20,
                  offset: const Offset(10, 10),
                ),
              if (!inset)
                BoxShadow(
                  color: shadowLight,
                  blurRadius: 20,
                  offset: const Offset(-10, -10),
                ),
              BoxShadow(
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
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
                          OwnerDashboardColors.brandPrimary(
                            context,
                          ).withValues(alpha: isDark ? 0.2 : 0.16),
                          AppColors.transparent,
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
                        OwnerDashboardColors.brandPrimary(
                          context,
                        ).withValues(alpha: isDark ? 0.14 : 0.1),
                        AppColors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -24,
                right: -18,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [liquidTint, AppColors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 140,
                  height: 140,
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
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
