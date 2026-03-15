import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Clips the nav bar with an animated, edge-safe cubic-bezier hollow semicircle
/// at [notchCenterX]. The notch slides between icon positions.
class BarWithNotchClipper extends CustomClipper<Path> {
  final double notchCenterX;
  final double notchRadius;
  final double notchDepth;
  final double topRadius;

  const BarWithNotchClipper({
    required this.notchCenterX,
    this.notchRadius = 34,
    this.notchDepth = 18,
    this.topRadius = 28,
  });

  @override
  Path getClip(Size size) {
    final cx = notchCenterX;
    final nr = notchRadius;
    final nd = notchDepth;
    final r = topRadius;

    // Clamp shoulder connection points so notch never overlaps corner radii.
    final leftX = math.max(r + 1.0, cx - nr - 8);
    final rightX = math.min(size.width - r - 1.0, cx + nr + 8);
    final lCtrl = math.max(r + 1.0, cx - nr);
    final rCtrl = math.min(size.width - r - 1.0, cx + nr);

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0); // top-left corner

    if (leftX > r + 1) path.lineTo(leftX, 0);

    path
      ..cubicTo(lCtrl, 0, cx - nr * 0.65, nd, cx, nd) // dip into notch
      ..cubicTo(cx + nr * 0.65, nd, rCtrl, 0, rightX, 0); // rise from notch

    if (rightX < size.width - r - 1) path.lineTo(size.width - r, 0);

    path
      ..quadraticBezierTo(size.width, 0, size.width, r) // top-right corner
      ..lineTo(size.width, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(BarWithNotchClipper old) =>
      old.notchCenterX != notchCenterX ||
      old.notchRadius != notchRadius ||
      old.notchDepth != notchDepth;
}
