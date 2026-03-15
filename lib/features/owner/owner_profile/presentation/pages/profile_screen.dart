import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_settings_provider.dart';
import 'package:rentdone/shared/widgets/profile_picture_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? avatarUrl;
  final bool isSetupMode;

  const ProfileScreen({super.key, this.avatarUrl, this.isSetupMode = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final ScrollController _scrollController;
  bool _dirty = false;
  bool _hasScrolledToSetup = false;
  static const _horizontalPadding = 20.0;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _scrollController = ScrollController();

    void markDirty() {
      if (_dirty) return;
      setState(() => _dirty = true);
    }

    _fullNameController.addListener(markDirty);
    _emailController.addListener(markDirty);
    _phoneController.addListener(markDirty);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _hydrate(OwnerProfileState profile) {
    if (_dirty || profile.isLoading) return;
    _fullNameController.text = profile.fullName;
    _emailController.text = profile.email;
    _phoneController.text = profile.phone;

    // In setup mode, scroll to the form card after first load
    if (widget.isSetupMode && !_hasScrolledToSetup && !profile.isLoading) {
      _hasScrolledToSetup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _resolvedLocationForSave(
    OwnerProfileState profile,
    OwnerSettingsState settings,
  ) {
    if (settings.locationAddress.trim().isNotEmpty) {
      return settings.locationAddress.trim();
    }

    if (settings.locationLatitude != null &&
        settings.locationLongitude != null) {
      return '${settings.locationLatitude!.toStringAsFixed(6)}, '
          '${settings.locationLongitude!.toStringAsFixed(6)}';
    }

    return profile.location;
  }

  Future<void> _save(
    OwnerProfileState profile,
    OwnerSettingsState settings,
  ) async {
    await ref
        .read(ownerProfileProvider.notifier)
        .saveProfile(
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          location: _resolvedLocationForSave(profile, settings),
        );
    if (mounted) {
      setState(() => _dirty = false);
      // In setup mode: if phone and name are now filled, go to dashboard
      if (widget.isSetupMode) {
        final name = _fullNameController.text.trim();
        final phone = _phoneController.text.trim();
        if (name.isNotEmpty && phone.isNotEmpty) {
          context.goNamed('ownerDashboard');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownerProfileProvider);
    final settings = ref.watch(ownerSettingsProvider);
    final settingsNotifier = ref.read(ownerSettingsProvider.notifier);
    _hydrate(profile);

    ref.listen(ownerProfileProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.successMessage != null && next.successMessage!.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }
    });

    final isDark = OwnerDashboardColors.isDark(context);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                context,
              ),
            ),
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            OwnerDashboardColors.brandPrimary(
                              context,
                            ).withValues(alpha: isDark ? 0.08 : 0.03),
                            AppColors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -70,
                    left: -40,
                    child: _bgBlob(
                      size: 180,
                      color: OwnerDashboardColors.ownerTopBlobColor(context),
                    ),
                  ),
                  Positioned(
                    right: -60,
                    top: 220,
                    child: _bgBlob(
                      size: 240,
                      color: OwnerDashboardColors.ownerBottomBlobColor(context),
                    ),
                  ),
                  Positioned(
                    bottom: -120,
                    left: -30,
                    child: _bgBlob(
                      size: 220,
                      color: OwnerDashboardColors.brandPrimary(
                        context,
                      ).withValues(alpha: isDark ? 0.10 : 0.05),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        profile.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  10,
                  _horizontalPadding,
                  120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.isSetupMode) _buildSetupBanner(context, profile),
                    if (widget.isSetupMode) const SizedBox(height: 14),
                    _buildProfileHeader(context, profile),
                    const SizedBox(height: 18),
                    _buildProfileFormCard(context, profile),
                    const SizedBox(height: 18),
                    _buildLocationCard(context, settings, settingsNotifier),
                    const SizedBox(height: 18),
                    _buildMetaCard(context, profile),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _bgBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  // ─── Setup Banner ──────────────────────────────────────────────────────────

  Widget _buildSetupBanner(BuildContext context, OwnerProfileState profile) {
    final isDark = OwnerDashboardColors.isDark(context);
    final missingFields = <String>[];
    if (profile.fullName.isEmpty && _fullNameController.text.trim().isEmpty) {
      missingFields.add('Full Name');
    }
    if (profile.email.isEmpty && _emailController.text.trim().isEmpty) {
      missingFields.add('Email');
    }
    if (profile.phone.isEmpty && _phoneController.text.trim().isEmpty) {
      missingFields.add('Phone Number');
    }
    if (profile.location.isEmpty) missingFields.add('Location');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFFB45309).withValues(alpha: 0.35),
                  const Color(0xFF92400E).withValues(alpha: 0.25),
                ]
              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
              : const Color(0xFFF59E0B).withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFF59E0B,
            ).withValues(alpha: isDark ? 0.20 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please fill in the highlighted fields below to continue using the app.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFFFCD34D).withValues(alpha: 0.85)
                        : const Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
                if (missingFields.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: missingFields.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              size: 12,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              f,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFF78350F),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, OwnerProfileState profile) {
    final isDark = OwnerDashboardColors.isDark(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 8,
          child: _bgBlob(
            size: 170,
            color: OwnerDashboardColors.brandPrimary(
              context,
            ).withValues(alpha: isDark ? 0.18 : 0.08),
          ),
        ),
        Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: CircularProfileAvatar(
                    photoUrl: profile.photoUrl,
                    email: profile.email,
                    radius: 60,
                    showBorder: true,
                    border: Border.all(
                      color: (isDark ? AppColors.white : AppColors.cFF0F172A)
                          .withValues(alpha: isDark ? 0.36 : 0.16),
                      width: 2,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () {
                      final next = profile.avatar == OwnerAvatar.male
                          ? OwnerAvatar.female
                          : OwnerAvatar.male;
                      ref.read(ownerProfileProvider.notifier).setAvatar(next);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              (isDark ? AppColors.white : AppColors.cFF0F172A)
                                  .withValues(alpha: isDark ? 0.6 : 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              profile.fullName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: OwnerDashboardColors.textPrimary(context),
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OwnerDashboardColors.textSecondary(context),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileFormCard(
    BuildContext context,
    OwnerProfileState profile,
  ) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final saveForeground = isDark ? AppColors.white : AppColors.cFF0F172A;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, 'Profile Details'),
          const SizedBox(height: 14),
          _glassInput(
            context,
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            requiresSetup:
                widget.isSetupMode && _fullNameController.text.trim().isEmpty,
          ),
          const SizedBox(height: 10),
          _glassInput(
            context,
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            requiresSetup:
                widget.isSetupMode && _emailController.text.trim().isEmpty,
          ),
          const SizedBox(height: 10),
          _glassInput(
            context,
            controller: _phoneController,
            label: 'Phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            requiresSetup:
                widget.isSetupMode && _phoneController.text.trim().isEmpty,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF3B82F6), Color(0xFF1E3A8A)]
                      : [
                          AppColors.cFFFFFFFF.withValues(alpha: 0.82),
                          brand.withValues(alpha: 0.16),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? brand.withValues(alpha: 0.45)
                      : OwnerDashboardColors.border(context),
                ),
                boxShadow: [
                  BoxShadow(
                    color: brand.withValues(alpha: isDark ? 0.35 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: saveForeground,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: profile.isSaving
                    ? null
                    : () => _save(profile, ref.read(ownerSettingsProvider)),
                icon: profile.isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: saveForeground,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(profile.isSaving ? 'Saving...' : 'Save Changes'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
  ) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final locationForeground = isDark ? AppColors.white : AppColors.cFF0F172A;
    final error = (settings.errorMessage ?? '').toLowerCase();
    final showLocationSettings = error.contains('service is disabled');
    final showAppSettings =
        error.contains('permission denied') ||
        error.contains('permanently denied');

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, 'Location'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark
                      ? brand.withValues(alpha: 0.24)
                      : AppColors.cFFFFFFFF.withValues(alpha: 0.78),
                  foregroundColor: locationForeground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: isDark
                          ? brand.withValues(alpha: 0.5)
                          : OwnerDashboardColors.border(context),
                    ),
                  ),
                ),
                onPressed: settings.isFetchingLocation
                    ? null
                    : () => notifier.captureCurrentLocation(),
                icon: settings.isFetchingLocation
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: locationForeground,
                        ),
                      )
                    : const Icon(Icons.gps_fixed_rounded),
                label: Text(
                  settings.isFetchingLocation
                      ? 'Capturing...'
                      : 'Capture Location',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoBlock(
            context,
            label: 'Address',
            value: settings.locationAddress.isNotEmpty
                ? settings.locationAddress
                : 'No location captured yet',
          ),
          const SizedBox(height: 10),
          _infoBlock(
            context,
            label: 'Coordinates',
            value:
                '${settings.locationLatitude?.toStringAsFixed(6) ?? 'N/A'}, '
                '${settings.locationLongitude?.toStringAsFixed(6) ?? 'N/A'}',
          ),
          if ((settings.errorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              settings.errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFFCA5A5)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showLocationSettings)
                  OutlinedButton.icon(
                    onPressed: () => notifier.openLocationSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Location Settings'),
                  ),
                if (showAppSettings)
                  OutlinedButton.icon(
                    onPressed: () => notifier.openAppSettings(),
                    icon: const Icon(Icons.app_settings_alt),
                    label: const Text('Open App Settings'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaCard(BuildContext context, OwnerProfileState profile) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, 'Account Details'),
          const SizedBox(height: 12),
          _metaRow(context, 'Role', profile.role),
          const SizedBox(height: 10),
          _metaRow(context, 'Status', profile.status),
          const SizedBox(height: 10),
          _metaRow(context, 'Member ID', profile.memberId),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    final isDark = OwnerDashboardColors.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (isDark ? AppColors.white : AppColors.cFFFFFFFF).withValues(
                  alpha: isDark ? 0.18 : 0.80,
                ),
                OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: isDark ? 0.10 : 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? AppColors.white : AppColors.cFF0F172A)
                  .withValues(alpha: isDark ? 0.16 : 0.09),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.24 : 0.09),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: isDark ? 0.16 : 0.08),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -28,
                right: -22,
                child: _bgBlob(
                  size: 96,
                  color: OwnerDashboardColors.brandPrimary(
                    context,
                  ).withValues(alpha: isDark ? 0.18 : 0.10),
                ),
              ),
              Positioned(
                bottom: -34,
                left: -18,
                child: _bgBlob(
                  size: 88,
                  color: OwnerDashboardColors.brandPrimary(
                    context,
                  ).withValues(alpha: isDark ? 0.12 : 0.06),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: OwnerDashboardColors.textPrimary(context),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _glassInput(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool requiresSetup = false,
  }) {
    final setupBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.8),
    );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: (_) =>
          setState(() {}), // rebuild so requiresSetup updates live
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: OwnerDashboardColors.textPrimary(context),
      ),
      cursorColor: OwnerDashboardColors.textPrimary(context),
      decoration: InputDecoration(
        labelText: requiresSetup ? '★  $label  (required)' : label,
        prefixIcon: Icon(
          icon,
          color: requiresSetup
              ? const Color(0xFFF59E0B)
              : OwnerDashboardColors.brandPrimary(context),
          size: 20,
        ),
        labelStyle: TextStyle(
          color: requiresSetup
              ? const Color(0xFFF59E0B)
              : OwnerDashboardColors.textSecondary(context),
          fontWeight: requiresSetup ? FontWeight.w600 : FontWeight.normal,
        ),
        filled: true,
        fillColor: requiresSetup
            ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
            : OwnerDashboardColors.brandPrimary(context).withValues(
                alpha: OwnerDashboardColors.isDark(context) ? 0.12 : 0.06,
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: requiresSetup
            ? setupBorder
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: OwnerDashboardColors.border(context),
                ),
              ),
        focusedBorder: requiresSetup
            ? setupBorder.copyWith(
                borderSide: const BorderSide(
                  color: Color(0xFFF59E0B),
                  width: 2,
                ),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 1.2,
                ),
              ),
      ),
    );
  }

  Widget _infoBlock(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OwnerDashboardColors.brandPrimary(
          context,
        ).withValues(alpha: OwnerDashboardColors.isDark(context) ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: OwnerDashboardColors.brandPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OwnerDashboardColors.textPrimary(context),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OwnerDashboardColors.textSecondary(context),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OwnerDashboardColors.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
