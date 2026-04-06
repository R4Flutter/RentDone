import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_settings_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_upi_provider.dart';
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

class OwnerBankDetailsScreen extends ConsumerStatefulWidget {
  const OwnerBankDetailsScreen({super.key});

  @override
  ConsumerState<OwnerBankDetailsScreen> createState() =>
      _OwnerBankDetailsScreenState();
}

class _OwnerBankDetailsScreenState
    extends ConsumerState<OwnerBankDetailsScreen> {
  late final TextEditingController _lateFeeController;
  late final TextEditingController _rentDueDayController;
  late final TextEditingController _upiController;

  @override
  void initState() {
    super.initState();
    _lateFeeController = TextEditingController();
    _rentDueDayController = TextEditingController();
    _upiController = TextEditingController();
  }

  @override
  void dispose() {
    _lateFeeController.dispose();
    _rentDueDayController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final settings = ref.watch(ownerSettingsProvider);
    final settingsNotifier = ref.read(ownerSettingsProvider.notifier);

    final ownerUpi = ref.watch(ownerUpiProvider);
    final ownerUpiNotifier = ref.read(ownerUpiProvider.notifier);

    _syncControllers(settings, ownerUpi);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    OwnerDashboardColors.managePropertiesBackgroundGradient(
                      context,
                    ),
              ),
            ),
          ),
          _liquidBlob(top: -78, left: -56, size: 300, isDark: isDark),
          _liquidBlob(bottom: -94, right: -60, size: 260, isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Defaults',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color:
                                    OwnerDashboardColors.managePropertiesHeaderPrimary(
                                      context,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configure default payment mode, rent policy, and owner UPI verification',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                color:
                                    OwnerDashboardColors.managePropertiesHeaderSecondary(
                                      context,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _statusPill(
                        context,
                        label: ownerUpi.isVerified
                            ? 'UPI Verified'
                            : 'UPI Pending',
                        icon: ownerUpi.isVerified
                            ? Icons.verified_rounded
                            : Icons.gpp_maybe_outlined,
                        color: ownerUpi.isVerified
                            ? AppTheme.successGreen
                            : AppTheme.warningAmber,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.wait([
                        ref.read(ownerSettingsProvider.notifier).load(),
                        ref.read(ownerUpiProvider.notifier).load(),
                      ]);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 940),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _glassSection(
                                context,
                                theme,
                                icon: Icons.payments_outlined,
                                title: 'Payments & Defaults',
                                subtitle:
                                    'Default mode, rent policy, and one-time owner UPI verification.',
                                child: _paymentSection(
                                  context,
                                  theme,
                                  settings,
                                  settingsNotifier,
                                  ownerUpi,
                                  ownerUpiNotifier,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _syncControllers(OwnerSettingsState settings, OwnerUpiState ownerUpi) {
    _setControllerText(_lateFeeController, settings.lateFeePercentage);
    _setControllerText(_rentDueDayController, settings.rentDueDay);
    _setControllerText(_upiController, ownerUpi.upiId);
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Widget _paymentSection(
    BuildContext context,
    ThemeData theme,
    OwnerSettingsState settings,
    OwnerSettingsNotifier settingsNotifier,
    OwnerUpiState ownerUpi,
    OwnerUpiNotifier ownerUpiNotifier,
  ) {
    const paymentModes = ['UPI', 'Cash'];
    final activeMode = paymentModes.contains(settings.defaultPaymentMode)
        ? settings.defaultPaymentMode
        : paymentModes.first;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          initialValue: activeMode,
          onChanged: (value) {
            if (value != null) {
              settingsNotifier.updateDefaultPaymentMode(value);
            }
          },
          borderRadius: BorderRadius.circular(14),
          dropdownColor: Theme.of(context).colorScheme.surface,
          decoration: _fieldDecoration(
            context,
            label: 'Default Payment Mode',
            helper: 'Applied as the default while creating new tenants.',
          ),
          items: paymentModes
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(
                    mode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _lateFeeController,
                onChanged: settingsNotifier.updateLateFeePercentage,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: _fieldDecoration(
                  context,
                  label: 'Late Fee',
                  helper: 'Auto-applied post due date.',
                  suffixText: '%',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _rentDueDayController,
                onChanged: settingsNotifier.updateRentDueDay,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: _fieldDecoration(
                  context,
                  label: 'Rent Due Day',
                  helper: 'Recommended range: 1 to 28.',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _upiController,
          enabled: !ownerUpi.isVerified,
          onChanged: ownerUpiNotifier.updateUpiId,
          decoration: _fieldDecoration(
            context,
            label: 'Owner UPI ID (one-time)',
            hint: 'example@okaxis',
            helper: ownerUpi.isVerified
                ? 'Verified once and locked for tenant onboarding safety.'
                : 'Set and verify once. This ID is reused app-wide.',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statusPill(
              context,
              label: ownerUpi.isVerified ? 'UPI Verified' : 'UPI Unverified',
              icon: ownerUpi.isVerified
                  ? Icons.verified_rounded
                  : Icons.gpp_maybe_outlined,
              color: ownerUpi.isVerified
                  ? AppTheme.successGreen
                  : AppTheme.warningAmber,
            ),
            const Spacer(),
            SizedBox(
              height: 38,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      OwnerDashboardColors.managePropertiesActionColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: ownerUpi.isLoading || ownerUpi.isVerified
                    ? null
                    : ownerUpiNotifier.verifyAndSaveUpi,
                icon: ownerUpi.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: AppLoadingIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined, size: 16),
                label: Text(ownerUpi.isVerified ? 'Verified' : 'Verify UPI'),
              ),
            ),
          ],
        ),
        if (ownerUpi.errorMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ownerUpi.errorMessage!,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (ownerUpi.successMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ownerUpi.successMessage!,
              style: const TextStyle(
                color: AppTheme.successGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _glassSection(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withAlpha(20), Colors.white.withAlpha(10)]
                  : [Colors.white.withAlpha(188), Colors.white.withAlpha(140)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withAlpha(48),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: OwnerDashboardColors.managePropertiesShadowColor(
                  context,
                ),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient:
                          OwnerDashboardColors.managePropertiesAccentGradient(
                            context,
                          ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                OwnerDashboardColors.managePropertiesHeaderPrimary(
                                  context,
                                ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color:
                                OwnerDashboardColors.managePropertiesHeaderSecondary(
                                  context,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    String? helper,
    String? suffixText,
  }) {
    final labelColor = OwnerDashboardColors.managePropertiesHeaderPrimary(
      context,
    ).withAlpha(235);
    final helperColor = OwnerDashboardColors.managePropertiesHeaderSecondary(
      context,
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      suffixText: suffixText,
      labelStyle: TextStyle(color: labelColor, fontWeight: FontWeight.w600),
      helperStyle: TextStyle(color: helperColor, fontSize: 11),
      hintStyle: TextStyle(
        color: OwnerDashboardColors.managePropertiesHeaderSecondary(context),
      ),
      filled: true,
      fillColor: AppTheme.pureWhite.withAlpha(90),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.liquidPrimaryStart.withAlpha(44),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.liquidPrimaryEnd.withAlpha(190),
          width: 1.2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: OwnerDashboardColors.managePropertiesPillBorder(context),
          width: 1.0,
        ),
      ),
    );
  }

  Widget _liquidBlob({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required bool isDark,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? AppTheme.liquidPrimaryStart.withAlpha(20)
              : AppTheme.liquidPrimaryStart.withAlpha(30),
        ),
      ),
    );
  }
}
