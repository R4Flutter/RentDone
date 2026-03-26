import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class TenantGlassTheme {
  TenantGlassTheme._();

  static bool isDark(BuildContext context) =>
      OwnerDashboardColors.isDark(context);

  static Color brand(BuildContext context) =>
      OwnerDashboardColors.brandPrimary(context);

  static Color brandStrong(BuildContext context) =>
      OwnerDashboardColors.brandPrimaryHover(context);

  static Color textPrimary(BuildContext context) =>
      OwnerDashboardColors.textPrimary(context);

  static Color textSecondary(BuildContext context) =>
      OwnerDashboardColors.textSecondary(context);

  static Color textMuted(BuildContext context) =>
      OwnerDashboardColors.textMuted(context);

  static Color surface(BuildContext context) =>
      OwnerDashboardColors.cardBackground(context);

  static Color elevated(BuildContext context) =>
      OwnerDashboardColors.elevatedBackground(context);

  static Color border(BuildContext context) =>
      OwnerDashboardColors.border(context);

  static Color success(BuildContext context) => AppTheme.successGreen;

  static Color warning(BuildContext context) => AppTheme.warningAmber;

  static Color error(BuildContext context) => AppTheme.errorRed;

  static LinearGradient surfaceGradient(BuildContext context, {Color? accent}) {
    final dark = isDark(context);
    final base = surface(context);
    final elevatedBase = elevated(context);
    final resolvedAccent = accent ?? brand(context);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, AppColors.white, dark ? 0.04 : 0.60) ?? base,
        Color.lerp(elevatedBase, resolvedAccent, dark ? 0.18 : 0.08) ??
            elevatedBase,
      ],
    );
  }

  static LinearGradient accentGradient(BuildContext context) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(
            surface(context),
            AppColors.white,
            isDark(context) ? 0.06 : 0.4,
          ) ??
          surface(context),
      Color.lerp(
            elevated(context),
            brand(context),
            isDark(context) ? 0.24 : 0.12,
          ) ??
          elevated(context),
      Color.lerp(
            surface(context),
            AppColors.black,
            isDark(context) ? 0.12 : 0.02,
          ) ??
          surface(context),
    ],
  );
}

class TenantGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool accent;

  const TenantGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.borderRadius,
    this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = TenantGlassTheme.isDark(context);
    final radius = borderRadius ?? BorderRadius.circular(16);

    final decoration = BoxDecoration(
      borderRadius: radius,
      gradient: accent
          ? TenantGlassTheme.accentGradient(context)
          : TenantGlassTheme.surfaceGradient(context),
      border: Border.all(
        color: accent
            ? TenantGlassTheme.brand(
                context,
              ).withValues(alpha: dark ? 0.24 : 0.14)
            : TenantGlassTheme.border(context),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.black.withValues(alpha: dark ? 0.22 : 0.10),
          blurRadius: 20,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: AppColors.white.withValues(alpha: dark ? 0.02 : 0.55),
          blurRadius: 16,
          offset: const Offset(-6, -6),
        ),
        if (accent)
          BoxShadow(
            color: TenantGlassTheme.brand(
              context,
            ).withValues(alpha: dark ? 0.18 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
      ],
    );

    final content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: width,
          margin: margin,
          decoration: decoration,
          padding: padding ?? const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: AppColors.transparent,
      borderRadius: radius,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

InputDecoration tenantGlassInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
}) {
  final hintColor = TenantGlassTheme.textMuted(context);
  final labelColor = TenantGlassTheme.textSecondary(context);
  final fillColor = TenantGlassTheme.elevated(context).withValues(alpha: 0.92);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: TenantGlassTheme.border(context)),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: labelColor),
    hintStyle: TextStyle(color: hintColor),
    filled: true,
    fillColor: fillColor,
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: TenantGlassTheme.brand(context)),
    ),
  );
}
