import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class AuthAuroraBackground extends StatelessWidget {
  const AuthAuroraBackground({
    required this.controller,
    required this.isDark,
    super.key,
  });
  final AnimationController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) => CustomPaint(
        painter: _AuroraPainter(controller.value, isDark),
        child: child,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _AuroraPainter(this.t, this.isDark);

  static const _p = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF020617), const Color(0xFF0A1628), const Color(0xFF0F172A)]
            : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF), const Color(0xFFF0F4FF)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    _blob(canvas, size,
      cx: size.width * 0.15 + 40 * math.sin(t * _p),
      cy: size.height * 0.18 + 30 * math.cos(t * _p * 0.7),
      r: size.width * 0.55,
      c: AppTheme.primaryBlue.withValues(alpha: isDark ? 0.22 : 0.15));

    _blob(canvas, size,
      cx: size.width * 0.82 + 35 * math.cos(t * _p * 1.3 + 1),
      cy: size.height * 0.72 + 40 * math.sin(t * _p * 0.9 + 2),
      r: size.width * 0.48,
      c: AppTheme.primaryHoverBlue.withValues(alpha: isDark ? 0.17 : 0.11));

    _blob(canvas, size,
      cx: size.width * 0.48 + 25 * math.sin(t * _p * 0.5 + 0.5),
      cy: size.height * 0.42 + 20 * math.cos(t * _p * 0.8 + 1),
      r: size.width * 0.32,
      c: isDark
          ? AppTheme.tenantTeal.withValues(alpha: 0.10)
          : const Color(0xFF818CF8).withValues(alpha: 0.08));

    _blob(canvas, size,
      cx: size.width * 0.72 + 30 * math.cos(t * _p * 0.6 + 2),
      cy: size.height * 0.28 + 25 * math.sin(t * _p * 1.1 + 0.5),
      r: size.width * 0.28,
      c: isDark
          ? const Color(0xFF6366F1).withValues(alpha: 0.08)
          : AppTheme.infoBlue.withValues(alpha: 0.09));

    _blob(canvas, size,
      cx: size.width * 0.25 + 20 * math.sin(t * _p * 0.9 + 3),
      cy: size.height * 0.78 + 35 * math.cos(t * _p * 0.5 + 1.5),
      r: size.width * 0.22,
      c: AppTheme.infoBlue.withValues(alpha: isDark ? 0.09 : 0.06));
  }

  void _blob(Canvas canvas, Size size,
      {required double cx, required double cy, required double r, required Color c}) {
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
