import 'package:flutter/material.dart';

class NavPainter extends CustomPainter {
  final int index;
  final Color backgroundColor;

  NavPainter({
    required this.index,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final itemWidth = size.width / 3;
    final centerX = itemWidth * index + itemWidth / 2;

    path.moveTo(0, 0);

    /// Left side to curve start
    path.lineTo(centerX - 45, 0);

    /// Curve Down
    path.quadraticBezierTo(
      centerX,
      55,
      centerX + 45,
      0,
    );

    /// Continue line
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NavPainter oldDelegate) {
    return oldDelegate.index != index;
  }
}