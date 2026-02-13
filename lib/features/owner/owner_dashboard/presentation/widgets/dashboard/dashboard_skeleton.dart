import 'package:flutter/material.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        _SkeletonBox(height: 32, width: 200),
        SizedBox(height: 24),

        Row(
          children: [
            Expanded(child: _SkeletonCard()),
            SizedBox(width: 16),
            Expanded(child: _SkeletonCard()),
            SizedBox(width: 16),
            Expanded(child: _SkeletonCard()),
          ],
        ),

        SizedBox(height: 24),

        Row(
          children: [
            Expanded(flex: 3, child: _SkeletonCard(height: 220)),
            SizedBox(width: 24),
            Expanded(flex: 2, child: _SkeletonCard(height: 220)),
          ],
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({this.height = 140});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      decoration: BoxDecoration(
        // Material 3 tonal surface
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double width;

  const _SkeletonBox({
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}