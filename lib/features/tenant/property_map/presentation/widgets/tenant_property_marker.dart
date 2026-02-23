import 'package:flutter/material.dart';

class TenantPropertyMarker extends StatelessWidget {
  final int vacantRooms;
  final bool selected;

  const TenantPropertyMarker({
    super.key,
    required this.vacantRooms,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Slightly larger if selected (optional)
    final size = selected ? 52.0 : 46.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Marker body
          Align(
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    spreadRadius: 1,
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.home_rounded,
                  size: selected ? 24 : 22,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          // Vacancy badge (top-right)
          Positioned(
            top: -6,
            right: -6,
            child: _Badge(
              text: vacantRooms.toString(),
              color: vacantRooms > 0 ? Colors.green : Colors.red,
            ),
          ),

          // Pointer tail (small triangle)
          Positioned(
            bottom: -10,
            left: (size / 2) - 8,
            child: CustomPaint(
              size: const Size(16, 12),
              painter: _TrianglePainter(
                color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
                borderColor: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _TrianglePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = borderColor;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}