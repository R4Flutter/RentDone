import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

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
    final titleColor = OwnerDashboardColors.managePropertiesHeaderPrimary(
      context,
    );
    final subtitleColor = OwnerDashboardColors.managePropertiesHeaderSecondary(
      context,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageMaxWidth = constraints.maxWidth * 0.34;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isDark ? 26 : 20,
                  sigmaY: isDark ? 26 : 20,
                ),
                child: Container(
                  height: 158,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.04),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0.55),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.liquidPrimaryStart.withValues(
                      alpha: isDark ? 0.22 : 0.26,
                    ),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.liquidShadow.withValues(
                        alpha: isDark ? 0.3 : 0.22,
                      ),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  ),                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient:
                                    OwnerDashboardColors.managePropertiesAccentGradient(
                                      context,
                                    ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'CONTINUE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: subtitleColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: imageMaxWidth,
                          maxHeight: 122,
                        ),
                        child: Transform.translate(
                          offset: const Offset(8, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.liquidPrimaryStart.withValues(
                                    alpha: 0.14,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
