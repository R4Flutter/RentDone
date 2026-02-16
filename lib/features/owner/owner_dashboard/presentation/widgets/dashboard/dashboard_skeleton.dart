import 'package:flutter/material.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _SkeletonBox(height: 32, width: 200),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1200 ? 4 : width >= 900 ? 3 : 2;
            final aspect = width >= 1200
                ? 1.35
                : width >= 900
                    ? 1.2
                    : 0.96;

            return GridView.count(
              shrinkWrap: true,
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: aspect,
              children: List.generate(
                4,
                (index) => const _SkeletonCard(),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (!isWide) {
              return Column(
                children: const [
                  _SkeletonCard(height: 200),
                  SizedBox(height: 16),
                  _SkeletonCard(height: 180),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _SkeletonCard(height: 200),
                      SizedBox(height: 16),
                      _SkeletonCard(height: 180),
                    ],
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _SkeletonCard(height: 240),
                ),
              ],
            );
          },
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
