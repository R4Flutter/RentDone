import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:rentdone/app/app_theme.dart';

class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = OwnerDashboardColors.isDark(context);
    final heroBase = OwnerDashboardColors.elevatedBackground(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: OwnerDashboardColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Overview of your rental business',
          style: textTheme.bodyMedium?.copyWith(
            color: OwnerDashboardColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    heroBase.withValues(alpha: isDark ? 0.76 : 0.86),
                    OwnerDashboardColors.brandPrimary(
                      context,
                    ).withValues(alpha: isDark ? 0.12 : 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OwnerDashboardColors.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(
                      alpha: isDark ? 0.3 : 0.12,
                    ),
                    blurRadius: 16,
                    offset: const Offset(8, 8),
                  ),
                  BoxShadow(
                    color: AppColors.white.withValues(
                      alpha: isDark ? 0.03 : 0.72,
                    ),
                    blurRadius: 14,
                    offset: const Offset(-8, -8),
                  ),
                  BoxShadow(
                    color: OwnerDashboardColors.brandPrimary(
                      context,
                    ).withValues(alpha: isDark ? 0.16 : 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -12,
                    top: -20,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            OwnerDashboardColors.brandPrimary(
                              context,
                            ).withValues(alpha: isDark ? 0.2 : 0.14),
                            AppColors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'This Month at a Glance',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Track collections, dues, and occupancy',
                                style: textTheme.bodySmall?.copyWith(
                                  color: OwnerDashboardColors.textSecondary(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Image.asset(
                            'assets/images/rentdone_logo.png',
                            height: 54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
