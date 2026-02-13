import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/sidebar_item.dart';

class DriveStyleTile extends StatelessWidget {
  const DriveStyleTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
   

    // 60%
    final colors = theme.colorScheme;

// 60%
final Color baseBg = colors.surface;

// 10%
final Color textColor = colors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? null : baseBg, // fallback
            gradient: selected
                ? AppTheme.blueSurfaceGradient // 🔥 30%
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: selected
                    ? AppTheme.pureWhite
                    : textColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? AppTheme.pureWhite
                        : textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}