import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';

import 'package:rentdone/shared/widgets/glass_role.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final shift = _bgController.value;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0C1224),
                              Color(0xFF111B33),
                              Color(0xFF141F3B),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFEEF3FF),
                              Color(0xFFE8F0FF),
                              Color(0xFFF8FAFF),
                            ],
                          ),
                  ),
                ),
              ),
              _liquidBlob(
                top: -90,
                left: -60,
                size: 320,
                color: isDark
                    ? const Color(0x404F7CFF)
                    : const Color(0x664F7CFF),
                travel: 16 * shift,
              ),
              _liquidBlob(
                bottom: -110,
                right: -70,
                size: 280,
                color: isDark
                    ? const Color(0x336FA8FF)
                    : const Color(0x556FA8FF),
                travel: -20 * shift,
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
                              color: AppTheme.pureWhite.withValues(
                                alpha: isDark ? 0.12 : 0.55,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.16),
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
          );
        },
      ),
    );
  }

  Widget _heroHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.65),
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.liquidShadow.withValues(alpha: isDark ? 0.25 : 0.15),
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.how_to_reg_rounded,
                      color: AppTheme.liquidPrimaryStart,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Choose your role',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: OwnerDashboardColors.managePropertiesHeaderPrimary(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Select how you want to use RentDone and continue with secure access.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: OwnerDashboardColors.managePropertiesHeaderSecondary(context),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
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
    double? right,
    double? bottom,
    required double size,
    required Color color,
    required double travel,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.translate(
        offset: Offset(travel, -travel * 0.45),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 70)],
          ),
        ),
      ),
    );
  }
}
