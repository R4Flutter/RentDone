import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String imagePath;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias, // 🔑 required for gradient clipping
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha:0.12), // theme-safe border
          width: 1,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.blueSurfaceGradient, // ✅ 30% BLUE SURFACE
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---------------------------------------------------------
            // IMAGE
            // ---------------------------------------------------------
            SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(width: 12),

            // ---------------------------------------------------------
            // TEXT CONTENT
            // ---------------------------------------------------------
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min, // prevents overflow
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: colors.onSurface.withValues(alpha:0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // VALUE
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: text.displayMedium?.copyWith(
                        color: colors.onSurface, // auto white / black
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // SUBTITLE
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha:0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}