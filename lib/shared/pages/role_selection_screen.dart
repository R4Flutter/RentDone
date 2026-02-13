
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rentdone/shared/widgets/glass_role.dart';


class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              /// TITLE
              Center(
                child: Text(
                  'Choose your role',
                  style: theme.textTheme.displayLarge?.copyWith(
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  'Select how you want to use RentDone',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              /// TENANT
              GlassRoleCard(
                title: 'Tenant',
                subtitle: 'Pay rent, track payments, stay organised',
                imagePath: 'assets/images/tenant_final.png',
                onTap: () {
                 context.pushNamed('login');
                },
              ),

              const SizedBox(height: 24),

              /// OWNER
              GlassRoleCard(
                title: 'Owner',
                subtitle: 'Manage properties & collect rent',
                imagePath: 'assets/images/owner_final.png',
                onTap: () {
                  context.pushNamed('ownerDashboard');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


