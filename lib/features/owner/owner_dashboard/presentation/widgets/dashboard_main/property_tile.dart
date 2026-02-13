import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

enum PropertyStatus { paid, vacant }

class PropertyTile extends StatelessWidget {
  const PropertyTile({
    super.key,
    required this.name,
    required this.tenant,
    required this.rent,
    required this.status,
  });

  final String name;
  final String tenant;
  final String rent;
  final PropertyStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final bool isVacant = status == PropertyStatus.vacant;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------------
            // STATUS INDICATOR
            // ---------------------------------------------------------
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 10,
              width: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isVacant
                    ? colors.error // vacant = error
                    : AppTheme.successGreen, // paid = success
              ),
            ),

            const SizedBox(width: 12),

            // ---------------------------------------------------------
            // CONTENT
            // ---------------------------------------------------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROPERTY NAME
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // TENANT INFO
                  Text(
                    isVacant ? 'Currently Vacant' : 'Tenant: $tenant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: isVacant
                          ? colors.error
                          : colors.onSurface.withValues(alpha:0.75),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // ---------------------------------------------------------
            // RENT + STATUS
            // ---------------------------------------------------------
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rent,
                  style: text.labelLarge?.copyWith(
                    color: colors.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  isVacant ? 'Vacant' : 'Paid',
                  style: text.bodyMedium?.copyWith(
                    color: isVacant
                        ? colors.error
                        : AppTheme.successGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}