import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/theme_mode_provider.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/notifications/push_notification_provider.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_glass.dart';

class TenantProfileScreen extends ConsumerStatefulWidget {
  final bool isSetupMode;
  const TenantProfileScreen({super.key, this.isSetupMode = false});

  @override
  ConsumerState<TenantProfileScreen> createState() =>
      _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _propertyFormKey = GlobalKey<FormState>();
  final _tenantNameController = TextEditingController();
  final _tenantEmailController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _propertyNameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  final _rentDueDayController = TextEditingController();

  Timer? _syncRetryTimer;
  int _syncAttempts = 0;
  bool _darkAppearanceEnabled = true;
  bool _notificationsEnabled = true;
  bool _isSavingNotificationPreference = false;
  bool _isSavingThemePreference = false;
  bool _isSavingProfile = false;
  bool _isSavingProperty = false;
  String? _activeTenantId;
  String? _notificationPreferenceUid;
  String? _themePreferenceTenantId;
  DateTime? _allocationDate;

  static const _maxSyncAttempts = 10;
  static const _syncRetryInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _stopAutoSync();
    _tenantNameController.dispose();
    _tenantEmailController.dispose();
    _tenantPhoneController.dispose();
    _propertyNameController.dispose();
    _roomNumberController.dispose();
    _monthlyRentController.dispose();
    _rentDueDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);

    return summaryAsync.when(
      loading: () => _profileScaffold(
        Center(
          child: CircularProgressIndicator(color: _ProfileTheme.brand(context)),
        ),
      ),
      error: (e, _) => _profileScaffold(
        Center(
          child: Text(
            'Profile load failed',
            style: TextStyle(color: _ProfileTheme.textPrimary(context)),
          ),
        ),
      ),
      data: (summary) {
        if (summary.tenantId.isEmpty) {
          _startAutoSyncIfNeeded();
          return _profileScaffold(
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _ProfileTheme.brand(context),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Profile sync is in progress. Details will appear automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ProfileTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        _stopAutoSync();
        _hydrateProfileFormIfNeeded(summary);
        _hydrateNotificationPreference();
        _hydrateThemePreference(summary.tenantId);

        return _profileScaffold(
          Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 128),
                children: [
                  _HeroIdentityCard(
                        tenantName: summary.tenantName,
                        profileImageUrl: summary.profileImageUrl,
                        trustScore: summary.trustScore,
                        trustBadge: summary.trustBadge,
                        onTrustScoreTap: () =>
                            _showTrustScoreBreakdown(summary),
                      )
                      .animate()
                      .fadeIn(duration: const Duration(milliseconds: 340))
                      .slideY(
                        begin: 0.08,
                        end: 0,
                        duration: const Duration(milliseconds: 340),
                      ),
                  const SizedBox(height: 14),
                  _PaymentReliabilityCard(
                        onTimeRate: summary.onTimePaymentRate,
                        delayedRate: summary.latePaymentRate,
                      )
                      .animate(delay: const Duration(milliseconds: 60))
                      .fadeIn(duration: const Duration(milliseconds: 300))
                      .slideY(
                        begin: 0.04,
                        end: 0,
                        duration: const Duration(milliseconds: 300),
                      ),
                  if (widget.isSetupMode) ...[
                    const SizedBox(height: 4),
                    _SetupBanner(
                      nameEmpty: _tenantNameController.text.trim().isEmpty,
                      phoneEmpty: _tenantPhoneController.text.trim().isEmpty,
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Personal Details'),
                  const SizedBox(height: 10),
                  _EditablePersonalDetailsCard(
                        formKey: _profileFormKey,
                        tenantNameController: _tenantNameController,
                        tenantEmailController: _tenantEmailController,
                        tenantPhoneController: _tenantPhoneController,
                        isSaving: _isSavingProfile,
                        onSave: () => _saveProfile(summary),
                      )
                      .animate(delay: const Duration(milliseconds: 90))
                      .fadeIn(duration: const Duration(milliseconds: 300)),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Property Allocation'),
                  const SizedBox(height: 10),
                  _EditablePropertyAllocationCard(
                        formKey: _propertyFormKey,
                        propertyNameController: _propertyNameController,
                        roomNumberController: _roomNumberController,
                        monthlyRentController: _monthlyRentController,
                        rentDueDayController: _rentDueDayController,
                        allocationDate: _allocationDate,
                        isSaving: _isSavingProperty,
                        onSelectDate: _pickAllocationDate,
                        onSave: () => _saveProperty(summary),
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
                          AppColors.transparent,
                          _ProfileTheme.brand(context).withValues(alpha: 0.34),
                          AppColors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                        darkAppearanceEnabled: _darkAppearanceEnabled,
                        notificationsEnabled: _notificationsEnabled,
                        isSavingNotificationPreference:
                            _isSavingNotificationPreference,
                        isSavingThemePreference: _isSavingThemePreference,
                        onDarkAppearanceChanged: _setDarkAppearanceEnabled,
                        onNotificationsChanged: _setNotificationsEnabled,
                      )
                      .animate(delay: const Duration(milliseconds: 190))
                      .fadeIn(duration: const Duration(milliseconds: 300)),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: TenantGlassTheme.error(
                          context,
                        ).withValues(alpha: 0.4),
                      ),
                      foregroundColor: _ProfileTheme.textPrimary(context),
                      backgroundColor: TenantGlassTheme.elevated(
                        context,
                      ).withValues(alpha: 0.82),
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
            ],
          ),
        );
      },
    );
  }

  void _hydrateNotificationPreference() {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null || uid.isEmpty || _notificationPreferenceUid == uid) {
      return;
    }

    _notificationPreferenceUid = uid;
    final pushService = ref.read(pushNotificationServiceProvider);
    unawaited(() async {
      final enabled = await pushService.isNotificationsEnabled(uid: uid);
      if (!mounted) return;
      setState(() => _notificationsEnabled = enabled);
    }());
  }

  void _hydrateThemePreference(String tenantId) {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty ||
        _themePreferenceTenantId == normalizedTenantId) {
      return;
    }

    _themePreferenceTenantId = normalizedTenantId;
    final service = ref.read(tenantFirestoreServiceProvider);

    unawaited(() async {
      try {
        final settings = await service.getTenantAppSettings(normalizedTenantId);
        final enabled = settings['darkAppearanceEnabled'] ?? true;
        if (!mounted) return;
        setState(() => _darkAppearanceEnabled = enabled);
        ref.read(appThemeModeProvider.notifier).setDarkMode(enabled);
      } catch (_) {
        // Keep existing in-memory mode on read failure.
      }
    }());
  }

  Future<void> _setDarkAppearanceEnabled(bool enabled) async {
    if (_isSavingThemePreference) {
      return;
    }

    final tenantId = (_activeTenantId ?? _themePreferenceTenantId ?? '').trim();
    final previous = _darkAppearanceEnabled;

    setState(() {
      _darkAppearanceEnabled = enabled;
      _isSavingThemePreference = true;
    });
    ref.read(appThemeModeProvider.notifier).setDarkMode(enabled);

    if (tenantId.isNotEmpty) {
      final service = ref.read(tenantFirestoreServiceProvider);
      try {
        await service.saveTenantAppSettings(
          tenantId: tenantId,
          darkAppearanceEnabled: enabled,
        );
      } catch (_) {
        if (!mounted) return;
        setState(() => _darkAppearanceEnabled = previous);
        ref.read(appThemeModeProvider.notifier).setDarkMode(previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update theme preference.')),
        );
      }
    }

    if (!mounted) return;
    setState(() => _isSavingThemePreference = false);
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    if (_isSavingNotificationPreference) {
      return;
    }

    final previous = _notificationsEnabled;
    setState(() {
      _notificationsEnabled = enabled;
      _isSavingNotificationPreference = true;
    });

    final pushService = ref.read(pushNotificationServiceProvider);
    try {
      await pushService.setNotificationsEnabled(enabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Notifications turned on.' : 'Notifications turned off.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update notification setting.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingNotificationPreference = false);
      }
    }
  }

  Widget _profileScaffold(Widget child) {
    return Container(
      decoration: BoxDecoration(gradient: _ProfileTheme.pageGradient(context)),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: _ProfileGlowOrb(
              color: _ProfileTheme.topBlob(context),
              size: 220,
            ),
          ),
          Positioned(
            top: 180,
            left: -70,
            child: _ProfileGlowOrb(
              color: _ProfileTheme.bottomBlob(context),
              size: 200,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Future<void> _showTrustScoreBreakdown(dynamic summary) async {
    final score = (summary.trustScore as int?) ?? 50;
    final badge = (summary.trustBadge as String?) ?? 'Average Tenant';
    final onTimeRate = ((summary.onTimePaymentRate as num?)?.toDouble() ?? 0)
        .clamp(0, 100);
    final delayedRate = ((summary.latePaymentRate as num?)?.toDouble() ?? 0)
        .clamp(0, 100);
    final dueDay = (summary.rentDueDay as int?) ?? 1;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: _ProfileTheme.sheetGradient(context),
            border: Border.all(color: TenantGlassTheme.border(context)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        color: _ProfileTheme.brand(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'How Your Trust Score Is Calculated',
                          style: TextStyle(
                            color: _ProfileTheme.textPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TrustMetaRow(label: 'Current Score', value: '$score / 100'),
                  _TrustMetaRow(label: 'Current Badge', value: badge),
                  _TrustMetaRow(
                    label: 'On-time Payments',
                    value: '${onTimeRate.toStringAsFixed(1)}%',
                  ),
                  _TrustMetaRow(
                    label: 'Delayed Payments',
                    value: '${delayedRate.toStringAsFixed(1)}%',
                  ),
                  _TrustMetaRow(
                    label: 'Rent Due Day',
                    value: '$dueDay every month',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Score Rules (Per Payment)',
                    style: TextStyle(
                      color: _ProfileTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _RuleLine(text: 'Pay before due date: +7 points'),
                  const _RuleLine(text: 'Pay on due date: +5 points'),
                  const _RuleLine(text: '1-3 days late: -5 points'),
                  const _RuleLine(text: '4-10 days late: -10 points'),
                  const _RuleLine(text: 'More than 10 days late: -15 points'),
                  const _RuleLine(text: 'Missed payment: -25 points'),
                  const SizedBox(height: 12),
                  Text(
                    'Consistency Bonus',
                    style: TextStyle(
                      color: _ProfileTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _RuleLine(
                    text: '6 consecutive on-time months: +10 bonus',
                  ),
                  const _RuleLine(
                    text: '12 consecutive on-time months: +20 bonus',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Badge Levels',
                    style: TextStyle(
                      color: _ProfileTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _RuleLine(text: '90-100: Trustworthy Pro'),
                  const _RuleLine(text: '70-89: Reliable Tenant'),
                  const _RuleLine(text: '50-69: Average Tenant'),
                  const _RuleLine(text: '20-49: Risky Tenant'),
                  const _RuleLine(text: '0-19: Untrustworthy'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.successGreen.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Tip: Pay rent on or before your due day each month to earn points and streak bonuses.',
                      style: TextStyle(
                        color: _ProfileTheme.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  void _hydrateProfileFormIfNeeded(dynamic summary) {
    if (_activeTenantId != summary.tenantId) {
      _activeTenantId = summary.tenantId;
      _tenantNameController.text = summary.tenantName;
      _tenantEmailController.text = summary.tenantEmail;
      _tenantPhoneController.text = summary.tenantPhone;
      _propertyNameController.text = summary.propertyName;
      _roomNumberController.text = summary.roomNumber;
      _monthlyRentController.text = summary.monthlyRent.toString();
      _rentDueDayController.text = summary.rentDueDay.toString();
      _allocationDate = summary.allocationDate;
      return;
    }

    if (_tenantNameController.text.trim().isEmpty &&
        summary.tenantName.trim().isNotEmpty) {
      _tenantNameController.text = summary.tenantName;
    }
    if (_tenantEmailController.text.trim().isEmpty &&
        summary.tenantEmail.trim().isNotEmpty) {
      _tenantEmailController.text = summary.tenantEmail;
    }
    if (_tenantPhoneController.text.trim().isEmpty &&
        summary.tenantPhone.trim().isNotEmpty) {
      _tenantPhoneController.text = summary.tenantPhone;
    }
    if (_propertyNameController.text.trim().isEmpty &&
        summary.propertyName.trim().isNotEmpty) {
      _propertyNameController.text = summary.propertyName;
    }
    if (_roomNumberController.text.trim().isEmpty &&
        summary.roomNumber.trim().isNotEmpty &&
        summary.roomNumber.trim() != '-') {
      _roomNumberController.text = summary.roomNumber;
    }
    if (_monthlyRentController.text.trim().isEmpty && summary.monthlyRent > 0) {
      _monthlyRentController.text = summary.monthlyRent.toString();
    }
    if (_rentDueDayController.text.trim().isEmpty && summary.rentDueDay > 0) {
      _rentDueDayController.text = summary.rentDueDay.toString();
    }
    _allocationDate ??= summary.allocationDate;
  }

  Future<void> _saveProfile(dynamic summary) async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      await saveTenantBasicDetails(
        ref,
        tenantId: summary.tenantId,
        tenantName: _tenantNameController.text.trim(),
        tenantEmail: _tenantEmailController.text.trim(),
        tenantPhone: _tenantPhoneController.text.trim(),
      );

      if (!mounted) return;

      final name = _tenantNameController.text.trim();
      final phone = _tenantPhoneController.text.trim();
      if (widget.isSetupMode && name.isNotEmpty && phone.isNotEmpty) {
        context.go('/tenant/dashboard');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _pickAllocationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _allocationDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked != null && mounted) {
      setState(() => _allocationDate = picked);
    }
  }

  Future<void> _saveProperty(dynamic summary) async {
    if (!(_propertyFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final monthlyRent = int.tryParse(_monthlyRentController.text.trim()) ?? 0;
    final rentDueDay = int.tryParse(_rentDueDayController.text.trim()) ?? 1;

    setState(() => _isSavingProperty = true);

    try {
      await saveTenantRoomDetails(
        ref,
        tenantId: summary.tenantId,
        details: TenantRoomDetails(
          propertyName: _propertyNameController.text.trim(),
          roomNumber: _roomNumberController.text.trim(),
          monthlyRent: monthlyRent,
          allocationDate: _allocationDate ?? DateTime.now(),
          rentDueDay: rentDueDay,
          depositAmount: summary.depositAmount,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property details updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update property: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSavingProperty = false);
      }
    }
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

class _ProfileTheme {
  static Color brand(BuildContext context) => TenantGlassTheme.brand(context);

  static Color brandStrong(BuildContext context) =>
      TenantGlassTheme.brandStrong(context);

  static Color textPrimary(BuildContext context) =>
      TenantGlassTheme.textPrimary(context);

  static Color textSecondary(BuildContext context) =>
      TenantGlassTheme.textSecondary(context);

  static LinearGradient pageGradient(BuildContext context) =>
      OwnerDashboardColors.ownerPageBackgroundGradient(context);

  static LinearGradient accentGradient(BuildContext context) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand(context), brandStrong(context)],
  );

  static LinearGradient sheetGradient(BuildContext context) =>
      TenantGlassTheme.surfaceGradient(context, accent: brand(context));

  static Color topBlob(BuildContext context) =>
      OwnerDashboardColors.ownerTopBlobColor(context);

  static Color bottomBlob(BuildContext context) =>
      OwnerDashboardColors.ownerBottomBlobColor(context);
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

class _SetupBanner extends StatelessWidget {
  final bool nameEmpty;
  final bool phoneEmpty;

  const _SetupBanner({required this.nameEmpty, required this.phoneEmpty});

  @override
  Widget build(BuildContext context) {
    final warning = TenantGlassTheme.warning(context);
    final missing = <String>[
      if (nameEmpty) 'Full Name',
      if (phoneEmpty) 'Phone Number',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            warning.withValues(alpha: 0.18),
            warning.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: warning.withValues(alpha: 0.38), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your profile',
                  style: TextStyle(
                    color: warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please fill in the highlighted fields below to get started.',
                  style: TextStyle(
                    color: _ProfileTheme.textPrimary(context),
                    fontSize: 12.5,
                  ),
                ),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: missing
                        .map(
                          (f) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: warning.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  f,
                                  style: TextStyle(
                                    color: warning,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: warning,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIdentityCard extends StatelessWidget {
  final String tenantName;
  final String? profileImageUrl;
  final int trustScore;
  final String trustBadge;
  final VoidCallback onTrustScoreTap;

  const _HeroIdentityCard({
    required this.tenantName,
    required this.profileImageUrl,
    required this.trustScore,
    required this.trustBadge,
    required this.onTrustScoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      accent: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _ProfileTheme.brand(context).withValues(alpha: 0.24),
                  blurRadius: 18,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundImage: (profileImageUrl ?? '').isNotEmpty
                  ? NetworkImage(profileImageUrl!)
                  : null,
              backgroundColor: _ProfileTheme.brand(
                context,
              ).withValues(alpha: 0.18),
              child: (profileImageUrl ?? '').isEmpty
                  ? Icon(
                      Icons.person,
                      color: _ProfileTheme.textPrimary(context),
                      size: 30,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tenantName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ProfileTheme.textPrimary(context),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _ProfileTheme.brand(context).withValues(alpha: 0.14),
                    border: Border.all(
                      color: _ProfileTheme.brand(
                        context,
                      ).withValues(alpha: 0.26),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: _ProfileTheme.brand(context),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        trustBadge,
                        style: TextStyle(
                          color: _ProfileTheme.textPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onTrustScoreTap,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                _TrustScoreRing(score: trustScore),
                const SizedBox(height: 6),
                Text(
                  'Tap to view rules',
                  style: TextStyle(
                    color: _ProfileTheme.textSecondary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditablePersonalDetailsCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController tenantNameController;
  final TextEditingController tenantEmailController;
  final TextEditingController tenantPhoneController;
  final bool isSaving;
  final VoidCallback onSave;

  const _EditablePersonalDetailsCard({
    required this.formKey,
    required this.tenantNameController,
    required this.tenantEmailController,
    required this.tenantPhoneController,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage your personal details',
              style: TextStyle(
                color: _ProfileTheme.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Name can be updated anytime. Email and phone are secured.',
              style: TextStyle(
                color: _ProfileTheme.textSecondary(context),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 12),
            _ProfileInputField(
              controller: tenantNameController,
              icon: Icons.person_outline,
              label: 'Full Name',
              carded: true,
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 10),
            _ProfileInputField(
              controller: tenantEmailController,
              icon: Icons.email_outlined,
              label: 'Email',
              carded: true,
              readOnly: true,
              protected: true,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            _ProfileInputField(
              controller: tenantPhoneController,
              icon: Icons.phone_outlined,
              label: 'Phone Number',
              carded: true,
              readOnly: true,
              protected: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: _ProfileTheme.brand(context),
                  foregroundColor: AppColors.white,
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(isSaving ? 'Saving...' : 'Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInputField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final bool protected;
  final bool carded;

  const _ProfileInputField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.protected = false,
    this.carded = false,
  });

  @override
  Widget build(BuildContext context) {
    final fieldRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _ProfileTheme.brand(context).withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: _ProfileTheme.brand(context), size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            readOnly: readOnly,
            style: TextStyle(color: _ProfileTheme.textPrimary(context)),
            decoration: tenantGlassInputDecoration(context, label: label)
                .copyWith(
                  suffixIcon: protected
                      ? Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: _ProfileTheme.textSecondary(context),
                        )
                      : null,
                ),
          ),
        ),
      ],
    );

    if (!carded) {
      return fieldRow;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: TenantGlassTheme.elevated(context).withValues(alpha: 0.94),
        border: Border.all(color: TenantGlassTheme.border(context)),
      ),
      child: fieldRow,
    );
  }
}

class _EditablePropertyAllocationCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController propertyNameController;
  final TextEditingController roomNumberController;
  final TextEditingController monthlyRentController;
  final TextEditingController rentDueDayController;
  final DateTime? allocationDate;
  final bool isSaving;
  final VoidCallback onSelectDate;
  final VoidCallback onSave;

  const _EditablePropertyAllocationCard({
    required this.formKey,
    required this.propertyNameController,
    required this.roomNumberController,
    required this.monthlyRentController,
    required this.rentDueDayController,
    required this.allocationDate,
    required this.isSaving,
    required this.onSelectDate,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final allocationText = allocationDate == null
        ? 'Select allocation date'
        : '${allocationDate!.day.toString().padLeft(2, '0')}/${allocationDate!.month.toString().padLeft(2, '0')}/${allocationDate!.year}';

    return TenantGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage your current property allocation',
              style: TextStyle(
                color: _ProfileTheme.textPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keep room, rent and due date accurate for billing.',
              style: TextStyle(
                color: _ProfileTheme.textSecondary(context),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 12),
            _ProfileInputField(
              controller: propertyNameController,
              icon: Icons.home_work_outlined,
              label: 'Property Name',
              carded: true,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Property name is required'
                  : null,
            ),
            const SizedBox(height: 10),
            _ProfileInputField(
              controller: roomNumberController,
              icon: Icons.meeting_room_outlined,
              label: 'Room Number',
              carded: true,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Room number is required'
                  : null,
            ),
            const SizedBox(height: 10),
            _ProfileInputField(
              controller: monthlyRentController,
              icon: Icons.currency_rupee,
              label: 'Monthly Rent',
              carded: true,
              keyboardType: TextInputType.number,
              validator: (value) {
                final rent = int.tryParse((value ?? '').trim()) ?? 0;
                if (rent <= 0) return 'Rent must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 10),
            _ProfileInputField(
              controller: rentDueDayController,
              icon: Icons.payments_outlined,
              label: 'Rent Due Day (1-31)',
              carded: true,
              keyboardType: TextInputType.number,
              validator: (value) {
                final day = int.tryParse((value ?? '').trim()) ?? 0;
                if (day < 1 || day > 31) {
                  return 'Enter a day between 1 and 31';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onSelectDate,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: TenantGlassTheme.elevated(
                    context,
                  ).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TenantGlassTheme.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _ProfileTheme.brand(
                          context,
                        ).withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.event_outlined,
                        color: _ProfileTheme.brand(context),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        allocationText,
                        style: TextStyle(
                          color: _ProfileTheme.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: _ProfileTheme.brand(context),
                  foregroundColor: AppColors.white,
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.home_work_rounded),
                label: Text(isSaving ? 'Saving...' : 'Save Property'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustScoreRing extends StatelessWidget {
  final int score;

  const _TrustScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final progress = (score / 100).clamp(0.0, 1.0);

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
                backgroundColor: TenantGlassTheme.elevated(
                  context,
                ).withValues(alpha: 0.9),
                valueColor: AlwaysStoppedAnimation(
                  _ProfileTheme.brand(context),
                ),
              ),
            ),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TenantGlassTheme.elevated(
                  context,
                ).withValues(alpha: 0.96),
                boxShadow: [
                  BoxShadow(
                    color: _ProfileTheme.brand(context).withValues(alpha: 0.2),
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
                    style: TextStyle(
                      color: _ProfileTheme.textPrimary(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'TRUST',
                    style: TextStyle(
                      color: _ProfileTheme.textSecondary(context),
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

class _PaymentReliabilityCard extends StatelessWidget {
  final double onTimeRate;
  final double delayedRate;

  const _PaymentReliabilityCard({
    required this.onTimeRate,
    required this.delayedRate,
  });

  @override
  Widget build(BuildContext context) {
    final safeOnTime = onTimeRate.clamp(0, 100).toDouble();
    final safeDelayed = delayedRate.clamp(0, 100).toDouble();

    return TenantGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Reliability',
            style: TextStyle(
              color: _ProfileTheme.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PaymentRateTile(
                  title: 'On-time',
                  rate: safeOnTime,
                  color: AppTheme.successGreen,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentRateTile(
                  title: 'Delayed',
                  rate: safeDelayed,
                  color: AppTheme.warningAmber,
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRateTile extends StatelessWidget {
  final String title;
  final double rate;
  final Color color;
  final IconData icon;

  const _PaymentRateTile({
    required this.title,
    required this.rate,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TenantGlassTheme.elevated(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TenantGlassTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: _ProfileTheme.textSecondary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${rate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _ProfileTheme.textPrimary(context),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 7,
              backgroundColor: TenantGlassTheme.elevated(
                context,
              ).withValues(alpha: 0.92),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
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
      style: TextStyle(
        color: _ProfileTheme.textPrimary(context),
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _TrustMetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _TrustMetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _ProfileTheme.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _ProfileTheme.textPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String text;

  const _RuleLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u2022 ',
            style: TextStyle(
              color: _ProfileTheme.brand(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _ProfileTheme.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool darkAppearanceEnabled;
  final bool notificationsEnabled;
  final bool isSavingNotificationPreference;
  final bool isSavingThemePreference;
  final ValueChanged<bool> onDarkAppearanceChanged;
  final ValueChanged<bool> onNotificationsChanged;

  const _SettingsCard({
    required this.darkAppearanceEnabled,
    required this.notificationsEnabled,
    required this.isSavingNotificationPreference,
    required this.isSavingThemePreference,
    required this.onDarkAppearanceChanged,
    required this.onNotificationsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Preferences',
            style: TextStyle(
              color: _ProfileTheme.textPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Control access and appearance settings.',
            style: TextStyle(
              color: _ProfileTheme.textSecondary(context),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          _PremiumToggleTile(
            icon: Icons.dark_mode_outlined,
            title: darkAppearanceEnabled ? 'Dark Mode' : 'Light Mode',
            value: darkAppearanceEnabled,
            enabled: !isSavingThemePreference,
            onChanged: onDarkAppearanceChanged,
          ),
          const SizedBox(height: 10),
          _PremiumToggleTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications',
            value: notificationsEnabled,
            enabled: !isSavingNotificationPreference,
            onChanged: onNotificationsChanged,
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
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PremiumToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: TenantGlassTheme.elevated(context).withValues(alpha: 0.94),
        border: Border.all(color: TenantGlassTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ProfileTheme.brand(context).withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: _ProfileTheme.brand(context), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: enabled
                    ? _ProfileTheme.textPrimary(context)
                    : _ProfileTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: enabled ? () => onChanged(!value) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: 52,
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: value ? _ProfileTheme.accentGradient(context) : null,
                color: value
                    ? null
                    : TenantGlassTheme.elevated(
                        context,
                      ).withValues(alpha: 0.98),
                border: Border.all(
                  color: value
                      ? _ProfileTheme.brand(context).withValues(alpha: 0.22)
                      : TenantGlassTheme.border(context),
                ),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: _ProfileTheme.brand(
                            context,
                          ).withValues(alpha: 0.26),
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
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
