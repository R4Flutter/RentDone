import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';

import 'package:rentdone/shared/widgets/glass_role.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.1),
              colors.surface,
              colors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.blueSurfaceGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your role',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select how you want to use RentDone and continue with secure access.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                GlassRoleCard(
                  title: 'Tenant',
                  subtitle: 'Pay rent, track payments, stay organised',
                  imagePath: 'assets/images/tenant_final.png',
                  onTap: () {
                    context.go('/login?role=tenant');
                  },
                ),

                const SizedBox(height: 18),

                GlassRoleCard(
                  title: 'Owner',
                  subtitle: 'Manage properties & collect rent',
                  imagePath: 'assets/images/owner_final.png',
                  onTap: () {
                    context.go('/login?role=owner');
                  },
                ),

                const Spacer(),

                Center(
                  child: Text(
                    'Role can be changed later from login',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.55),
                    ),
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
