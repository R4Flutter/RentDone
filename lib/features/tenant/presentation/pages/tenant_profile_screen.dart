import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_glass.dart';

class TenantProfileScreen extends ConsumerStatefulWidget {
  const TenantProfileScreen({super.key});

  @override
  ConsumerState<TenantProfileScreen> createState() =>
      _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen> {
  Timer? _syncRetryTimer;
  int _syncAttempts = 0;
  bool _biometricEnabled = true;
  bool _darkAppearanceEnabled = true;

  static const _maxSyncAttempts = 10;
  static const _syncRetryInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _stopAutoSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);

    return summaryAsync.when(
      loading: () =>
          _profileScaffold(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _profileScaffold(
        Center(
          child: Text(
            'Profile load failed',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ),
      ),
      data: (summary) {
        if (summary.tenantId.isEmpty) {
          _startAutoSyncIfNeeded();
          return _profileScaffold(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 12),
                    Text(
                      'Profile sync is in progress. Details will appear automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        _stopAutoSync();

        return _profileScaffold(
          Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 128),
                children: [
                  _HeroIdentityCard(
                        tenantName: summary.tenantName,
                        tenantId: summary.tenantId,
                        profileImageUrl: summary.profileImageUrl,
                        trustScore: 742,
                      )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 340))
                      .slideY(
                        begin: 0.08,
                        end: 0,
                        duration: const Duration(milliseconds: 340),
                      ),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Personal Details'),
                  const SizedBox(height: 10),
                  _InfoSectionCard(
                        items: [
                          _InfoItemData(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: summary.tenantEmail,
                          ),
                          _InfoItemData(
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            value: summary.tenantPhone,
                          ),
                        ],
                      )
                      .animate(delay: const Duration(milliseconds: 90))
                      .fadeIn(duration: const Duration(milliseconds: 300)),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Property Allocation'),
                  const SizedBox(height: 10),
                  _InfoSectionCard(
                        items: [
                          _InfoItemData(
                            icon: Icons.home_work_outlined,
                            label: 'Property Name',
                            value: summary.propertyName,
                          ),
                          _InfoItemData(
                            icon: Icons.meeting_room_outlined,
                            label: 'Room Number',
                            value: summary.roomNumber,
                          ),
                          _InfoItemData(
                            icon: Icons.payments_outlined,
                            label: 'Rent Due Day',
                            value: 'Day ${summary.rentDueDay}',
                          ),
                        ],
                      )
                      .animate(delay: const Duration(milliseconds: 140))
                      .fadeIn(duration: const Duration(milliseconds: 300)),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Settings'),
                  const SizedBox(height: 6),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _ProfileTokens.highlightAccent.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                        biometricEnabled: _biometricEnabled,
                        darkAppearanceEnabled: _darkAppearanceEnabled,
                        onBiometricChanged: (value) {
                          setState(() => _biometricEnabled = value);
                        },
                        onDarkAppearanceChanged: (value) {
                          setState(() => _darkAppearanceEnabled = value);
                        },
                      )
                      .animate(delay: const Duration(milliseconds: 190))
                      .fadeIn(duration: const Duration(milliseconds: 300)),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _ProfileTokens.danger.withValues(alpha: 0.5),
                      ),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.03),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Log out',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 20,
                bottom: 86,
                child: _QuickActionsFab(
                  onTap: () => _showQuickActionsSheet(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileScaffold(Widget child) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ProfileTokens.bgTop,
            _ProfileTokens.bgMiddle,
            _ProfileTokens.bgBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: _ProfileGlowOrb(
              color: _ProfileTokens.primaryAccent.withValues(alpha: 0.24),
              size: 220,
            ),
          ),
          Positioned(
            top: 180,
            left: -70,
            child: _ProfileGlowOrb(
              color: _ProfileTokens.secondaryAccent.withValues(alpha: 0.2),
              size: 200,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Future<void> _showQuickActionsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17263D), Color(0xFF101A2D)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickActionItem(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                onTap: () => Navigator.pop(context),
              ),
              _QuickActionItem(
                icon: Icons.wallet_outlined,
                title: 'Update Documents',
                onTap: () {
                  Navigator.pop(context);
                  this.context.go('/tenant/documents');
                },
              ),
              _QuickActionItem(
                icon: Icons.support_agent_outlined,
                title: 'Contact Owner',
                onTap: () {
                  Navigator.pop(context);
                  this.context.go('/tenant/tenancy-details');
                },
              ),
              _QuickActionItem(
                icon: Icons.security_outlined,
                title: 'Security Settings',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Security settings coming soon'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startAutoSyncIfNeeded() {
    if (_syncRetryTimer != null || !mounted) {
      return;
    }

    _syncAttempts = 0;
    _syncRetryTimer = Timer.periodic(_syncRetryInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      final hasTenantId = ref
          .read(tenantDashboardProvider)
          .maybeWhen(
            data: (summary) => summary.tenantId.isNotEmpty,
            orElse: () => false,
          );

      if (hasTenantId) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      _syncAttempts += 1;
      ref.invalidate(tenantDashboardProvider);

      if (_syncAttempts >= _maxSyncAttempts) {
        timer.cancel();
        _syncRetryTimer = null;
      }
    });
  }

  void _stopAutoSync() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  Future<void> _logout() async {
    try {
      await ref.read(signOutUseCaseProvider).call();
    } catch (_) {
      await ref.read(firebaseAuthProvider).signOut();
    }

    if (!mounted) return;
    context.go('/role');
  }
}

class _ProfileTokens {
  static const Color bgTop = Color(0xFF0B1220);
  static const Color bgMiddle = Color(0xFF0F1C2E);
  static const Color bgBottom = Color(0xFF111C30);

  static const Color primaryAccent = Color(0xFF4F7CFF);
  static const Color secondaryAccent = Color(0xFF7A5CFF);
  static const Color highlightAccent = Color(0xFF3FE0FF);
  static const Color danger = Color(0xFFFF5A5F);
}

class _ProfileGlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _ProfileGlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: 95, spreadRadius: 8)],
        ),
      ),
    );
  }
}

class _HeroIdentityCard extends StatelessWidget {
  final String tenantName;
  final String tenantId;
  final String? profileImageUrl;
  final int trustScore;

  const _HeroIdentityCard({
    required this.tenantName,
    required this.tenantId,
    required this.profileImageUrl,
    required this.trustScore,
  });

  @override
  Widget build(BuildContext context) {
    final displayId = tenantId.isEmpty
        ? '-'
        : tenantId.substring(0, tenantId.length > 10 ? 10 : tenantId.length);

    return TenantGlassCard(
      accent: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _ProfileTokens.highlightAccent.withValues(
                        alpha: 0.38,
                      ),
                      blurRadius: 20,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundImage: (profileImageUrl ?? '').isNotEmpty
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.28),
                  child: (profileImageUrl ?? '').isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 32)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tenant ID • $displayId',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              _TrustScoreRing(score: trustScore),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustScoreRing extends StatelessWidget {
  final int score;

  const _TrustScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final progress = (score / 1000).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: progress),
      builder: (context, value, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(
                  _ProfileTokens.highlightAccent,
                ),
              ),
            ),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: _ProfileTokens.primaryAccent.withValues(alpha: 0.32),
                    blurRadius: 20,
                    spreadRadius: -8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    score.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'TRUST',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 8,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _InfoItemData {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItemData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _InfoSectionCard extends StatelessWidget {
  final List<_InfoItemData> items;

  const _InfoSectionCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _InfoRow(item: items[index]),
            if (index != items.length - 1)
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 18),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final _InfoItemData item;

  const _InfoRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Icon(
            item.icon,
            color: Colors.white.withValues(alpha: 0.85),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.value.isEmpty ? 'Not available' : item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool biometricEnabled;
  final bool darkAppearanceEnabled;
  final ValueChanged<bool> onBiometricChanged;
  final ValueChanged<bool> onDarkAppearanceChanged;

  const _SettingsCard({
    required this.biometricEnabled,
    required this.darkAppearanceEnabled,
    required this.onBiometricChanged,
    required this.onDarkAppearanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          _PremiumToggleTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric Access',
            value: biometricEnabled,
            onChanged: onBiometricChanged,
          ),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 18),
          _PremiumToggleTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Appearance',
            value: darkAppearanceEnabled,
            onChanged: onDarkAppearanceChanged,
          ),
        ],
      ),
    );
  }
}

class _PremiumToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PremiumToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.86),
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: value
                  ? const LinearGradient(
                      colors: [
                        _ProfileTokens.primaryAccent,
                        _ProfileTokens.secondaryAccent,
                      ],
                    )
                  : null,
              color: value ? null : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: value
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.2),
              ),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: _ProfileTokens.primaryAccent.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 20,
                        spreadRadius: -6,
                      ),
                    ]
                  : null,
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionsFab extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickActionsFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  _ProfileTokens.primaryAccent,
                  _ProfileTokens.secondaryAccent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _ProfileTokens.primaryAccent.withValues(alpha: 0.52),
                  blurRadius: 26,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 0.97,
          end: 1.03,
          duration: const Duration(milliseconds: 1400),
        );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TenantGlassCard(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _ProfileTokens.primaryAccent.withValues(alpha: 0.22),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}
