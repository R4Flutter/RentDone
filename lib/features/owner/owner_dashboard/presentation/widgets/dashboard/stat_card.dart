import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final OwnerDashboardTone tone;
  final String? assetPath;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = OwnerDashboardColors.isDark(context);
    final onSurface = OwnerDashboardColors.textPrimary(context);
    final secondary = OwnerDashboardColors.textSecondary(context);
    final bubbleBase = OwnerDashboardColors.brandPrimary(
      context,
    ).withValues(alpha: 0.14);
    final bubbleBorder = OwnerDashboardColors.brandPrimary(
      context,
    ).withValues(alpha: 0.3);
    final bubbleText = OwnerDashboardColors.brandPrimary(context);

    return DashboardCard(
      useGradient: false,
      backgroundColor: OwnerDashboardColors.cardBackground(context),
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          if (assetPath != null)
            Positioned(
              right: -10,
              top: 6,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  assetPath!,
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                  color: OwnerDashboardColors.brandPrimary(
                    context,
                  ).withValues(alpha: isDark ? 0.24 : 0.18),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bubbleBase,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: bubbleBorder),
                    ),
                    child: Icon(icon, color: bubbleText, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleBase,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: textTheme.labelLarge?.copyWith(
                          color: bubbleText,
                          fontSize: 11,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                width: 140,
                child: Center(
                  child: FittedBox(
                    alignment: Alignment.center,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: secondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: OwnerDashboardColors.brandPrimary(context),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
