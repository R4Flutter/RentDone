import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.nearBlack,
      extendBody: true,
      body: SafeArea(
        child: Container(color: AppTheme.nearBlack, child: widget.child),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNav(
              context,
              calculateIndex(context),
              avatarUrl: user?.photoURL,
            ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    int currentIndex, {
    required String? avatarUrl,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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
