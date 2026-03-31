import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_tenant_summary.dart';

class TenantCard extends StatelessWidget {
  const TenantCard({super.key, required this.tenant, required this.onTap});

  final OwnerTenantSummary tenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = tenant.status == 'active';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: DashboardCard(
        radius: 18,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: 0.15),
              child: Text(
                tenant.name.isEmpty ? '-' : tenant.name[0].toUpperCase(),
                style: TextStyle(
                  color: OwnerDashboardColors.brandPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: OwnerDashboardColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Room ${tenant.roomNumber} | Rs ${tenant.rentAmount}/month',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OwnerDashboardColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color:
                    (isActive ? AppTheme.successGreen : AppTheme.warningAmber)
                        .withValues(alpha: 0.16),
                border: Border.all(
                  color:
                      (isActive ? AppTheme.successGreen : AppTheme.warningAmber)
                          .withValues(alpha: 0.50),
                ),
              ),
              child: Text(
                isActive ? 'Active' : 'Vacant',
                style: TextStyle(
                  color: isActive
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
