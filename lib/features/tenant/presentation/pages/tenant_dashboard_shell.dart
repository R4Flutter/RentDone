import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/shared/widgets/back_handler.dart';

class TenantDashboardShell extends ConsumerStatefulWidget {
  final Widget child;
  const TenantDashboardShell({super.key, required this.child});

  @override
  ConsumerState<TenantDashboardShell> createState() =>
      _TenantDashboardShellState();
}

class _TenantDashboardShellState extends ConsumerState<TenantDashboardShell> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final user = ref.watch(firebaseAuthProvider).currentUser;

    int calculateIndex(BuildContext context) {
      final location = GoRouterState.of(context).uri.toString();
      if (location.contains('/tenant/transactions')) return 1;
      if (location.contains('/tenant/documents')) return 2;
      if (location.contains('/tenant/profile')) return 3;
      return 0;
    }

    return BackHandler.root(
      dialogTitle: 'Exit RentDone?',
      dialogMessage: 'Are you sure you want to exit?',
      child: Scaffold(
        backgroundColor: AppTheme.nearBlack,
        extendBody: true,
        drawer: const _TenantSideDrawer(),
        body: SafeArea(
          bottom: false,
          child: Container(color: AppTheme.nearBlack, child: widget.child),
        ),
        bottomNavigationBar: isDesktop
            ? null
            : _buildBottomNav(
                context,
                calculateIndex(context),
                avatarUrl: user?.photoURL,
              ),
      ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    int currentIndex, {
    required String? avatarUrl,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        decoration: BoxDecoration(
          color: AppTheme.nearBlack,
          border: Border(
            top: BorderSide(color: scheme.onPrimary.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(
              context,
              Icons.home_outlined,
              'Home',
              0,
              currentIndex,
              () => context.go('/tenant/dashboard'),
            ),
            _navIcon(
              context,
              Icons.receipt_long_rounded,
              'Payments',
              1,
              currentIndex,
              () => context.go('/tenant/transactions'),
            ),
            _navIcon(
              context,
              Icons.wallet_outlined,
              'Vault',
              2,
              currentIndex,
              () => context.go('/tenant/documents'),
            ),
            GestureDetector(
              onTap: () => context.go('/tenant/profile'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: currentIndex == 3
                        ? AppTheme.primaryBlue
                        : scheme.onPrimary.withValues(alpha: 0.2),
                    backgroundImage: (avatarUrl ?? '').isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: (avatarUrl ?? '').isEmpty
                        ? Icon(
                            Icons.person,
                            size: 12,
                            color: currentIndex == 3
                                ? scheme.onPrimary
                                : scheme.onPrimary.withValues(alpha: 0.85),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 11,
                      color: currentIndex == 3
                          ? scheme.onPrimary
                          : scheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    int currentIndex,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? scheme.onPrimary
                  : scheme.onPrimary.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? scheme.onPrimary
                    : scheme.onPrimary.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantSideDrawer extends StatelessWidget {
  const _TenantSideDrawer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      width: 300,
      backgroundColor: AppTheme.nearBlack,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.white.withValues(alpha: 0.08),
                    ),
                    child: Icon(
                      Icons.dashboard_customize_rounded,
                      color: scheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tenant Menu',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Divider(color: AppColors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 16),
              _DrawerItem(
                icon: Icons.report_problem_outlined,
                label: 'Complaints',
                subtitle: 'Submit & track issues',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/complaints');
                },
              ),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.lock_outline_rounded,
                label: 'Document Vault',
                subtitle: 'Secure file storage',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/documents');
                },
              ),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.receipt_long_rounded,
                label: 'Payments',
                subtitle: 'History & dues',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/transactions');
                },
              ),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                subtitle: 'Account details',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/tenant/profile');
                },
              ),
              const Spacer(),
              Divider(color: AppColors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 8),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                subtitle: 'App preferences',
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onPrimary.withValues(alpha: 0.4),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
