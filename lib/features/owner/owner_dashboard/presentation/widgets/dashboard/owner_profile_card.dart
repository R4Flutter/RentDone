import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';

class OwnerProfileCard extends StatelessWidget {
  const OwnerProfileCard({super.key, required this.profile});

  final OwnerProfileState profile;

  @override
  Widget build(BuildContext context) {
    return LiquidProfileCard(profile: profile);
  }
}

class LiquidProfileCard extends StatefulWidget {
  const LiquidProfileCard({super.key, required this.profile});

  final OwnerProfileState profile;

  @override
  State<LiquidProfileCard> createState() => _LiquidProfileCardState();
}

class _LiquidProfileCardState extends State<LiquidProfileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final isDark = OwnerDashboardColors.isDark(context);
    final width = _cardWidth(MediaQuery.of(context).size.width);
    final profile = widget.profile;

    final normalizedEmail = profile.email.trim().toLowerCase();
    final avatarSeed = normalizedEmail.isNotEmpty
        ? normalizedEmail
        : (profile.memberId.trim().isNotEmpty
              ? profile.memberId.trim()
              : profile.fullName.trim());
    final diceBearUrl =
        'https://api.dicebear.com/7.x/identicon/png?seed=${Uri.encodeComponent(avatarSeed)}';

    final cardBackground = AppColors.white.withValues(
      alpha: isDark ? 0.08 : 0.06,
    );
    final borderColors = <Color>[
      AppColors.cFF8B5CF6.withValues(alpha: 0.70),
      AppColors.cFF3B82F6.withValues(alpha: 0.70),
      AppColors.cFF22D3EE.withValues(alpha: 0.70),
    ];

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.92, end: 1),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: value, child: child),
          );
        },
        child: SizedBox(
          width: width,
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: borderColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cFF8B5CF6.withValues(
                    alpha: isDark ? 0.28 : 0.20,
                  ),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white.withValues(alpha: isDark ? 0.11 : 0.16),
                        AppColors.white.withValues(alpha: isDark ? 0.05 : 0.07),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GlassPill(
                            label: 'RentDone Elite',
                            textColor: textPrimary,
                            background: AppColors.white.withValues(alpha: 0.13),
                            border: AppColors.white.withValues(alpha: 0.26),
                          ),
                          const Spacer(),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white.withValues(alpha: 0.12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cFF22D3EE.withValues(
                                    alpha: 0.30,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: AppColors.cFF22D3EE,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulse.value,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 102,
                            height: 102,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.cFF8B5CF6,
                                  AppColors.cFF22D3EE,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cFF8B5CF6.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                diceBearUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return profile.photoUrl.trim().isNotEmpty
                                      ? Image.network(
                                          profile.photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Image.asset(
                                                  profile.avatar.assetPath,
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                        )
                                      : Image.asset(
                                          profile.avatar.assetPath,
                                          fit: BoxFit.cover,
                                        );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          profile.fullName.trim().isEmpty
                              ? 'Raj Naik'
                              : profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          profile.role,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textSecondary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(icon: Icons.phone_outlined, text: profile.phone),
                      const SizedBox(height: 8),
                      _InfoRow(icon: Icons.email_outlined, text: profile.email),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: _displayLocation(profile.location),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.successGreen.withValues(
                                  alpha: 0.50,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.successGreen.withValues(
                                    alpha: 0.30,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: AppTheme.successGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _memberId(profile.memberId),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _TagChip(label: '#rentdone', textColor: textPrimary),
                          _TagChip(label: '#owner', textColor: textPrimary),
                          _TagChip(label: '#dashboard', textColor: textPrimary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _memberId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '#RD-AWCE';
    return value.startsWith('#') ? value : '#$value';
  }

  String _displayLocation(String rawLocation) {
    final value = rawLocation.trim();
    if (value.isEmpty) return 'Location unavailable';

    final coordinatePattern = RegExp(
      r'^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$',
    );
    if (coordinatePattern.hasMatch(value)) {
      return 'Goa, India';
    }
    return value;
  }

  double _cardWidth(double screenWidth) {
    final target = screenWidth * 0.85;
    if (target < 280) return 280;
    if (target > 420) return 420;
    return target;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: textSecondary),
          ),
        ),
      ],
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color background;
  final Color border;

  const _GlassPill({
    required this.label,
    required this.textColor,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color textColor;

  const _TagChip({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
