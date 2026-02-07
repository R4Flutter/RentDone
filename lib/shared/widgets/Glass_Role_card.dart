import 'dart:ui';
import 'package:rentdone/app/app_theme.dart';
import 'package:flutter/material.dart';

class GlassRoleCard extends StatelessWidget {
  const GlassRoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 22 : 16,
            sigmaY: isDark ? 22 : 16,
          ),
          child: Container(
            height: 150,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // 🔥 GRADIENT GLASS (DARK)
              gradient: isDark ? AppTheme.blueSurfaceGradient : null,

              // 🌤 LIGHT GLASS
              color: isDark
                  ? null
                  : AppTheme.lightBlueSurface.withValues(alpha: 0.75),

              borderRadius: BorderRadius.circular(28),

              // ✨ GLASS BORDER
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(
                  alpha: isDark ? 0.18 : 0.22,
                ),
              ),
            ),
            child: Row(
              children: [
                /// TEXT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                /// IMAGE
                Transform.translate(
                  offset: const Offset(12, 0),
                  child: Image.asset(
                    imagePath,
                    width: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
