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
  final bool useBlur;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.useGradient = false,
    this.gradient,
    this.backgroundColor,
    this.inset = false,
    this.useBlur = false, // Default to false for better performance
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

    final shadowDark = AppColors.black.withValues(alpha: isDark ? 0.2 : 0.08);
    final shellColor =
        resolvedColor ??
        Color.lerp(baseColor, AppColors.white, isDark ? 0.08 : 0.22)!;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: useBlur
            ? shellColor.withValues(alpha: isDark ? 0.72 : 0.82)
            : shellColor,
        gradient: resolvedGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.0,
        ),
        boxShadow: [
          if (inset)
            BoxShadow(
              color: shadowDark,
              blurRadius: 10,
              offset: const Offset(2, 2),
              blurStyle: BlurStyle.inner,
            ),
          if (!inset)
            BoxShadow(
              color: shadowDark,
              blurRadius: 16,
              offset: const Offset(0, 8),
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
                      ).withValues(alpha: isDark ? 0.12 : 0.08),
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
                    ).withValues(alpha: isDark ? 0.1 : 0.06),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    if (useBlur) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: cardContent,
        ),
      );
    }

    return RepaintBoundary(child: cardContent);
  }
}

