import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';

import 'package:rentdone/shared/widgets/glass_role.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    OwnerDashboardColors.managePropertiesBackgroundGradient(
                      context,
                    ),
              ),
            ),
          ),
          _liquidBlob(
            top: -85,
            left: -65,
            size: 320,
            isDark: isDark,
            color: AppTheme.liquidPrimaryStart,
          ),
          _liquidBlob(
            bottom: -95,
            right: -70,
            size: 280,
            isDark: isDark,
            color: AppTheme.liquidPrimaryEnd,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heroHeader(context),
                  const SizedBox(height: 18),
                  Text(
                    'Continue as',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                        context,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassRoleCard(
                    title: 'Tenant',
                    subtitle: 'Pay rent, track payments, and manage your stay',
                    imagePath: 'assets/images/tenant_final.png',
                    onTap: () {
                      context.go('/phone?role=tenant');
                    },
                  ),
                  const SizedBox(height: 14),
                  GlassRoleCard(
                    title: 'Owner',
                    subtitle: 'Manage properties, tenants, and collection flow',
                    imagePath: 'assets/images/owner_final.png',
                    onTap: () {
                      context.go('/phone?role=owner');
                    },
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.pureWhite.withAlpha(
                            isDark ? 30 : 140,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.liquidPrimaryStart.withAlpha(40),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color:
                                  OwnerDashboardColors.managePropertiesHeaderSecondary(
                                    context,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Role can be changed later from login',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      OwnerDashboardColors.managePropertiesHeaderSecondary(
                                        context,
                                      ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroHeader(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.liquidPrimaryStart.withAlpha(232),
                AppTheme.liquidPrimaryEnd.withAlpha(214),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.liquidShadow.withAlpha(75),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.white.withAlpha(48),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.how_to_reg_rounded,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose your role',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Select how you want to use RentDone and continue with secure access.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withAlpha(222),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liquidBlob({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required bool isDark,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(isDark ? 24 : 36),
        ),
      ),
    );
  }
}
