import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class TenantDashboardShell extends ConsumerWidget {
  final Widget child;

  const TenantDashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    int calculateIndex(BuildContext context) {
      final location = GoRouterState.of(context).uri.toString();
      if (location.contains('/tenant/transactions')) return 1;
      if (location.contains('/tenant/profile')) return 2;
      return 0;
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppTheme.pureWhite,
      extendBody: true,
      drawer: _buildDrawer(context, ref),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, scaffoldKey),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _buildBottomNav(context, calculateIndex(context)),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: scheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.email ?? 'Tenant',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tenant Account',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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
                _drawerItem(
                  context,
                  Icons.receipt_long_rounded,
                  'Payment History',
                  () {
                    Navigator.pop(context);
                    context.go('/tenant/transactions');
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
                const Divider(height: 24, indent: 16, endIndent: 16),
                _drawerItem(context, Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context);
                  // TODO: Add settings page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings coming soon!')),
                  );
                }),
                _drawerItem(
                  context,
                  Icons.help_outline_rounded,
                  'Help & Support',
                  () {
                    Navigator.pop(context);
                    // TODO: Add support page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support coming soon!')),
                    );
                  },
                ),
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
    final color = isDestructive ? Colors.red : theme.colorScheme.onSurface;

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(signOutUseCaseProvider).call();
        if (context.mounted) {
          context.go('/roleSelection');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildTopBar(
    BuildContext context,
    GlobalKey<ScaffoldState> scaffoldKey,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset('assets/images/rentdone_logo.png', height: 32),
          const SizedBox(width: 12),
          Text(
            'RentDone',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return Container(
      height: 85,
      decoration: const BoxDecoration(gradient: AppTheme.blueSurfaceGradient),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(
            context,
            Icons.dashboard_rounded,
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
            Icons.person_outline_rounded,
            'Profile',
            2,
            currentIndex,
            () => context.go('/tenant/profile'),
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
    final isSelected = currentIndex == index;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
