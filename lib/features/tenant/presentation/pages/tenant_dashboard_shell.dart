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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final displayEmail = (user?.email ?? '').trim().isNotEmpty
        ? user!.email!
        : 'Tenant';
    final scheme = Theme.of(context).colorScheme;

    int calculateIndex(BuildContext context) {
      final location = GoRouterState.of(context).uri.toString();
      if (location.contains('/tenant/transactions')) return 1;
      if (location.contains('/tenant/documents')) return 2;
      if (location.contains('/tenant/profile')) return 3;
      return 0;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.nearBlack,
      extendBody: true,
      drawer: _buildDrawer(context, ref, displayEmail),
      body: SafeArea(
        child: Container(color: AppTheme.nearBlack, child: widget.child),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNav(
              context,
              calculateIndex(context),
              avatarUrl: user?.photoURL,
              onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.45),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              child: Icon(Icons.add, color: scheme.onPrimary),
            ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    WidgetRef ref,
    String displayEmail,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Drawer(
      backgroundColor: AppTheme.nearBlack,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            decoration: const BoxDecoration(
              gradient: AppTheme.blueSurfaceGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  child: Icon(Icons.person, size: 40, color: scheme.onPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  displayEmail,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tenant Account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(context, Icons.dashboard_rounded, 'Dashboard', () {
                  Navigator.pop(context);
                  context.go('/tenant/dashboard');
                }),
                _drawerItem(context, Icons.wallet_outlined, 'Vault', () {
                  Navigator.pop(context);
                  context.go('/tenant/documents');
                }),
                _drawerItem(
                  context,
                  Icons.report_problem_outlined,
                  'Complaints',
                  () {
                    Navigator.pop(context);
                    context.go('/tenant/complaints');
                  },
                ),
                _drawerItem(
                  context,
                  Icons.receipt_long_rounded,
                  'Payments',
                  () {
                    Navigator.pop(context);
                    context.go('/tenant/transactions');
                  },
                ),
                _drawerItem(
                  context,
                  Icons.home_work_outlined,
                  'Tenancy Details',
                  () {
                    Navigator.pop(context);
                    context.go('/tenant/tenancy-details');
                  },
                ),
                _drawerItem(
                  context,
                  Icons.person_outline_rounded,
                  'Profile',
                  () {
                    Navigator.pop(context);
                    context.go('/tenant/profile');
                  },
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                _drawerItem(context, Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          _drawerItem(
            context,
            Icons.logout_rounded,
            'Logout',
            () => _handleLogout(context, ref),
            isDestructive: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? AppTheme.errorRed
        : theme.colorScheme.onPrimary;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(signOutUseCaseProvider).call();
      } catch (e) {
        await ref.read(firebaseAuthProvider).signOut();
      }

      if (context.mounted) {
        context.go('/role');
      }
    }
  }

  Widget _buildBottomNav(
    BuildContext context,
    int currentIndex, {
    required String? avatarUrl,
    required VoidCallback onOpenMenu,
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
            onLongPress: onOpenMenu,
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
