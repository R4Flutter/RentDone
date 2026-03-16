import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_bank_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_settings_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_upi_provider.dart';

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

  late final TextEditingController _holderController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _ifscController;
  late final TextEditingController _branchController;

  @override
  void initState() {
    super.initState();
    _lateFeeController = TextEditingController();
    _rentDueDayController = TextEditingController();
    _upiController = TextEditingController();
    _holderController = TextEditingController();
    _bankNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _ifscController = TextEditingController();
    _branchController = TextEditingController();
  }

  @override
  void dispose() {
    _lateFeeController.dispose();
    _rentDueDayController.dispose();
    _upiController.dispose();
    _holderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _branchController.dispose();
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

    final bank = ref.watch(ownerBankProvider);
    final bankNotifier = ref.read(ownerBankProvider.notifier);

    _syncControllers(settings, ownerUpi, bank);

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
                              'Bank Details',
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
                              'Production-ready payout and payment configuration',
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
                        label: bank.isDirty ? 'Unsynced' : 'Synced',
                        icon: bank.isDirty
                            ? Icons.cloud_off_outlined
                            : Icons.cloud_done,
                        color: bank.isDirty
                            ? AppTheme.warningAmber
                            : AppTheme.successGreen,
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
                        ref.read(ownerBankProvider.notifier).refresh(),
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
                              const SizedBox(height: 18),
                              _glassSection(
                                context,
                                theme,
                                icon: Icons.account_balance_outlined,
                                title: 'Bank Account Verification',
                                subtitle:
                                    'Secure account details used for invoices, reminders, and transfers.',
                                child: _bankSection(
                                  context,
                                  theme,
                                  bank,
                                  bankNotifier,
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

  void _syncControllers(
    OwnerSettingsState settings,
    OwnerUpiState ownerUpi,
    OwnerBankState bank,
  ) {
    _setControllerText(_lateFeeController, settings.lateFeePercentage);
    _setControllerText(_rentDueDayController, settings.rentDueDay);
    _setControllerText(_upiController, ownerUpi.upiId);

    _setControllerText(_holderController, bank.accountHolderName);
    _setControllerText(_bankNameController, bank.bankName);
    _setControllerText(_accountNumberController, bank.accountNumber);
    _setControllerText(_ifscController, bank.ifsc);
    _setControllerText(_branchController, bank.branch);
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
    const paymentModes = ['UPI', 'Cash', 'Bank Transfer'];
    final activeMode = paymentModes.contains(settings.defaultPaymentMode)
        ? settings.defaultPaymentMode
        : paymentModes.first;

    return Column(
      children: [
        DropdownButtonFormField<String>(
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
              .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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

  Widget _bankSection(
    BuildContext context,
    ThemeData theme,
    OwnerBankState bank,
    OwnerBankNotifier notifier,
  ) {
    return Column(
      children: [
        Row(
          children: [
            _statusPill(
              context,
              label: bank.isVerified ? 'Bank Verified' : 'Needs Verification',
              icon: bank.isVerified
                  ? Icons.verified_user
                  : Icons.pending_actions,
              color: bank.isVerified
                  ? AppTheme.successGreen
                  : AppTheme.warningAmber,
            ),
            const SizedBox(width: 8),
            if (bank.updatedAt != null)
              _statusPill(
                context,
                label: 'Synced ${_formatSyncTime(bank.updatedAt!)}',
                icon: Icons.sync,
                color: OwnerDashboardColors.managePropertiesActionColor(
                  context,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _holderController,
          onChanged: notifier.updateAccountHolderName,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            context,
            label: 'Account Holder Name',
            hint: 'As per bank records',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bankNameController,
          onChanged: notifier.updateBankName,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            context,
            label: 'Bank Name',
            hint: 'HDFC Bank, ICICI Bank, SBI, etc.',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _accountNumberController,
                onChanged: notifier.updateAccountNumber,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                  context,
                  label: 'Account Number',
                  hint: '6-20 digits',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _ifscController,
                onChanged: notifier.updateIfsc,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(11),
                ],
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(
                  context,
                  label: 'IFSC',
                  hint: 'HDFC0001234',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _branchController,
          onChanged: notifier.updateBranch,
          textInputAction: TextInputAction.done,
          decoration: _fieldDecoration(
            context,
            label: 'Branch (Optional)',
            hint: 'Branch name or city',
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Account preview: ${_maskAccountNumber(_accountNumberController.text)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                context,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        OwnerDashboardColors.managePropertiesActionColor(
                          context,
                        ),
                    side: BorderSide(
                      color: OwnerDashboardColors.managePropertiesActionColor(
                        context,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: bank.isLoading ? null : notifier.refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        OwnerDashboardColors.managePropertiesActionColor(
                          context,
                        ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: bank.isLoading
                      ? null
                      : notifier.verifyAndSaveBankDetails,
                  icon: bank.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shield_rounded, size: 18),
                  label: Text(
                    bank.isVerified && !bank.isDirty
                        ? 'Saved & Verified'
                        : 'Save & Verify',
                  ),
                ),
              ),
            ),
          ],
        ),
        if (bank.errorMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              bank.errorMessage!,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (bank.successMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              bank.successMessage!,
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

  String _maskAccountNumber(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Not entered';
    if (clean.length <= 4) return clean;
    final lastFour = clean.substring(clean.length - 4);
    return 'XXXXXX$lastFour';
  }

  String _formatSyncTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
