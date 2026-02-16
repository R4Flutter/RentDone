import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_di.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/owner_profile_card.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';

class OwnerMobileDrawer extends ConsumerStatefulWidget {
  const OwnerMobileDrawer({super.key});

  @override
  ConsumerState<OwnerMobileDrawer> createState() =>
      _OwnerMobileDrawerState();
}

class _OwnerMobileDrawerState extends ConsumerState<OwnerMobileDrawer> {
  final GlobalKey _headerKey = GlobalKey();

  void _openProfileCard(OwnerProfileState profile) {
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final headerContext = _headerKey.currentContext;

    Offset startOffset = Offset.zero;
    if (overlayBox != null && headerContext != null) {
      final headerBox = headerContext.findRenderObject() as RenderBox?;
      if (headerBox != null) {
        final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
        final headerOrigin = headerBox.localToGlobal(Offset.zero);
        final headerCenter =
            headerOrigin - overlayOrigin + headerBox.size.center(Offset.zero);
        final overlayCenter = overlayBox.size.center(Offset.zero);
        startOffset = headerCenter - overlayCenter;
      }
    }

    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Owner profile',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ProfileCardDialog(
          animation: animation,
          startOffset: startOffset,
          profile: profile,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final location = uri.toString();

    final profile = ref.watch(ownerProfileProvider);
    final displayName = profile.fullName;
    final email = profile.email;
    final avatarAsset = profile.avatar.assetPath;

    final paymentsStatus = uri.queryParameters['status']?.toLowerCase();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _profileHeader(
              context,
              headerKey: _headerKey,
              name: displayName,
              email: email,
              avatarAsset: avatarAsset,
              onTap: () => _openProfileCard(profile),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _drawerItem(
                    context,
                    icon: Icons.person_outline,
                    label: 'Profile',
                    selected: location.contains('/owner/profile'),
                    onTap: () => _go(context, '/owner/profile'),
                  ),
                  const SizedBox(height: 6),
                  _drawerItem(
                    context,
                    icon: Icons.people_outline,
                    label: 'Manage Tenants',
                    selected: location.contains('/owner/tenants/manage'),
                    onTap: () => _go(context, '/owner/tenants/manage'),
                  ),
                  const SizedBox(height: 6),
                  _drawerItem(
                    context,
                    icon: Icons.apartment_outlined,
                    label: 'Manage Properties',
                    selected: location.contains('/owner/properties'),
                    onTap: () => _go(context, '/owner/properties'),
                  ),
                  const SizedBox(height: 6),
                  _expansionSection(
                    context,
                    title: 'Transactions',
                    icon: Icons.account_balance_wallet_outlined,
                    initiallyExpanded: location.contains('/owner/payments'),
                    children: [
                      _drawerItem(
                        context,
                        icon: Icons.check_circle_outline,
                        label: 'Collected Payments',
                        selected: location.contains('/owner/payments') &&
                            paymentsStatus == 'paid',
                        dense: true,
                        onTap: () =>
                            _go(context, '/owner/payments?status=paid'),
                      ),
                      _drawerItem(
                        context,
                        icon: Icons.hourglass_bottom_outlined,
                        label: 'Pending Payments',
                        selected: location.contains('/owner/payments') &&
                            paymentsStatus == 'pending',
                        dense: true,
                        onTap: () =>
                            _go(context, '/owner/payments?status=pending'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _expansionSection(
                    context,
                    title: 'Reports',
                    icon: Icons.bar_chart_outlined,
                    initiallyExpanded: location.contains('/owner/reports'),
                    children: [
                      _drawerItem(
                        context,
                        icon: Icons.calendar_month_outlined,
                        label: 'Monthly Summary',
                        selected: location.contains('/owner/reports'),
                        dense: true,
                        onTap: () => _go(
                          context,
                          '/owner/reports?type=monthly',
                        ),
                      ),
                      _drawerItem(
                        context,
                        icon: Icons.calendar_today_outlined,
                        label: 'Annual Summary',
                        selected: location.contains('/owner/reports'),
                        dense: true,
                        onTap: () => _go(
                          context,
                          '/owner/reports?type=annual',
                        ),
                      ),
                      _drawerItem(
                        context,
                        icon: Icons.meeting_room_outlined,
                        label: 'Occupancy Report',
                        selected: location.contains('/owner/reports'),
                        dense: true,
                        onTap: () => _go(
                          context,
                          '/owner/reports?type=occupancy',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _drawerItem(
                    context,
                    icon: Icons.notifications_outlined,
                    label: 'Notifications / Alerts',
                    selected: location.contains('/owner/notifications'),
                    onTap: () => _go(context, '/owner/notifications'),
                  ),
                  const SizedBox(height: 6),
                  _drawerItem(
                    context,
                    icon: Icons.settings_outlined,
                    label: 'App Settings',
                    selected: location.contains('/owner/settings'),
                    onTap: () => _go(context, '/owner/settings'),
                  ),
                  const SizedBox(height: 6),
                  _drawerItem(
                    context,
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    selected: location.contains('/owner/support'),
                    onTap: () => _go(context, '/owner/support'),
                  ),
                  const SizedBox(height: 12),
                  _drawerItem(
                    context,
                    icon: Icons.logout,
                    label: 'Logout',
                    selected: false,
                    danger: true,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader(
    BuildContext context, {
    Key? headerKey,
    required String name,
    required String email,
    required String avatarAsset,
    String? avatarUrl,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: headerKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : AssetImage(avatarAsset) as ImageProvider,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    bool dense = false,
    bool danger = false,
    VoidCallback? onTap,
  }) {
    final color = danger ? Colors.red : null;
    return Material(
      color: selected ? Colors.blue.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        dense: dense,
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
      ),
    );
  }

  Widget _expansionSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon),
        title: Text(title),
        childrenPadding: const EdgeInsets.only(left: 8, bottom: 6),
        children: children,
      ),
    );
  }

  void _go(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.go(location);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(logoutOwnerUseCaseProvider).call();
    if (!mounted) return;
    context.go('/login');
  }
}

class _ProfileCardDialog extends StatelessWidget {
  const _ProfileCardDialog({
    required this.animation,
    required this.startOffset,
    required this.profile,
  });

  final Animation<double> animation;
  final Offset startOffset;
  final OwnerProfileState profile;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final flight = Curves.easeInOutCubic.transform(animation.value);
        final spin = Tween<double>(begin: 0.9, end: 0.0).transform(flight);
        final tilt = Tween<double>(begin: 0.5, end: 0.0).transform(flight);
        final scaleCurve = animation.status == AnimationStatus.reverse
            ? Curves.easeInCubic
            : Curves.easeOutBack;
        final scale =
            Tween<double>(begin: 0.72, end: 1.0).transform(scaleCurve.transform(
          animation.value,
        ));
        final offset =
            Offset.lerp(startOffset, Offset.zero, flight) ?? Offset.zero;
        final scrimOpacity = 0.55 * Curves.easeOut.transform(animation.value);

        return Material(
          color: Colors.black.withValues(alpha: scrimOpacity),
          child: SafeArea(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: GestureDetector(
                    onTap: () {},
                    child: Transform.translate(
                      offset: offset,
                      child: Transform.scale(
                        scale: scale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(tilt)
                            ..rotateZ(spin),
                          child: OwnerProfileCard(profile: profile),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
