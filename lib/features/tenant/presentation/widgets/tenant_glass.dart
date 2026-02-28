import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(16);

    final decoration = BoxDecoration(
      borderRadius: radius,
      gradient: accent
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.34),
                AppTheme.primaryBlue.withValues(alpha: 0.22),
                AppTheme.nearBlack.withValues(alpha: 0.56),
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.09),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
      border: Border.all(
        color: accent
            ? scheme.onPrimary.withValues(alpha: 0.24)
            : scheme.onPrimary.withValues(alpha: 0.14),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 18,
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
      color: Colors.transparent,
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
  final hintColor = Colors.white.withValues(alpha: 0.45);
  final labelColor = Colors.white.withValues(alpha: 0.72);
  final fillColor = Colors.white.withValues(alpha: 0.05);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
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
      borderSide: const BorderSide(color: AppTheme.primaryBlue),
    ),
  );
}
