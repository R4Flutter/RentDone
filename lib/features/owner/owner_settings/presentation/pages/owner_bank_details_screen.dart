import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_bank_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_settings_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_upi_provider.dart';

class OwnerBankDetailsScreen extends ConsumerWidget {
  const OwnerBankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(ownerSettingsProvider);
    final settingsNotifier = ref.read(ownerSettingsProvider.notifier);
    final ownerUpi = ref.watch(ownerUpiProvider);
    final ownerUpiNotifier = ref.read(ownerUpiProvider.notifier);
    final bank = ref.watch(ownerBankProvider);
    final notifier = ref.read(ownerBankProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Bank Details'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeader(theme),
                const SizedBox(height: 24),
                _sectionCard(
                  theme,
                  icon: Icons.payments_outlined,
                  title: 'Payments',
                  subtitle: 'Default modes, rent policies, and owner UPI.',
                  child: _paymentSection(
                    settings,
                    settingsNotifier,
                    ownerUpi,
                    ownerUpiNotifier,
                    theme,
                  ),
                ),
                const SizedBox(height: 24),
                _sectionCard(
                  theme,
                  icon: Icons.account_balance_outlined,
                  title: 'Bank Details',
                  subtitle: 'Used in WhatsApp and invoices.',
                  child: _bankSection(bank, notifier, theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageHeader(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bank Details', style: theme.textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Add bank information for transfers and WhatsApp reminders.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        _statusPill(
          label: 'Auto-saved',
          icon: Icons.cloud_done,
          color: AppTheme.successGreen,
        ),
      ],
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ThemeData theme, {
    required String label,
    String? hint,
    String? helper,
    String? suffixText,
  }) {
    final labelColor = theme.colorScheme.onPrimary.withValues(alpha: 0.85);
    final helperColor = theme.colorScheme.onPrimary.withValues(alpha: 0.6);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      suffixText: suffixText,
      labelStyle: TextStyle(color: labelColor),
      helperStyle: TextStyle(color: helperColor),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _paymentSection(
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    OwnerUpiState ownerUpi,
    OwnerUpiNotifier ownerUpiNotifier,
    ThemeData theme,
  ) {
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    const paymentModes = ['UPI', 'Cash', 'Bank Transfer'];
    final effectiveMode = paymentModes.contains(settings.defaultPaymentMode)
        ? settings.defaultPaymentMode
        : paymentModes.first;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: effectiveMode,
          onChanged: (value) {
            if (value != null) {
              notifier.updateDefaultPaymentMode(value);
            }
          },
          style: textStyle,
          dropdownColor: theme.colorScheme.surface,
          decoration: _fieldDecoration(
            theme,
            label: 'Default Payment Mode',
            helper: 'Used when creating new tenant agreements.',
          ),
          items: paymentModes
              .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: settings.lateFeePercentage,
          onChanged: notifier.updateLateFeePercentage,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            LengthLimitingTextInputFormatter(5),
          ],
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Late Fee Percentage',
            suffixText: '%',
            helper: 'Applied after rent due date.',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: settings.rentDueDay,
          onChanged: notifier.updateRentDueDay,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Rent Due Day',
            helper: '1 to 28 recommended for stable billing.',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: ownerUpi.upiId,
          enabled: !ownerUpi.isVerified,
          onChanged: ownerUpiNotifier.updateUpiId,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Owner UPI ID (one-time)',
            helper: ownerUpi.isVerified
                ? 'Verified once. Locked for future tenant adds.'
                : 'Set once and verify. It will be reused automatically.',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statusPill(
              label: ownerUpi.isVerified ? 'Verified' : 'Not verified',
              icon: ownerUpi.isVerified
                  ? Icons.verified
                  : Icons.shield_outlined,
              color: ownerUpi.isVerified
                  ? AppTheme.successGreen
                  : AppTheme.warningAmber,
            ),
            const Spacer(),
            FilledButton(
              onPressed: ownerUpi.isLoading || ownerUpi.isVerified
                  ? null
                  : ownerUpiNotifier.verifyAndSaveUpi,
              child: ownerUpi.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(ownerUpi.isVerified ? 'Verified' : 'Verify & Save'),
            ),
          ],
        ),
        if (ownerUpi.errorMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ownerUpi.errorMessage!,
              style: const TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
        if (ownerUpi.successMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ownerUpi.successMessage!,
              style: const TextStyle(color: AppTheme.successGreen),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bankSection(
    OwnerBankState bank,
    OwnerBankNotifier notifier,
    ThemeData theme,
  ) {
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Column(
      children: [
        TextFormField(
          initialValue: bank.accountHolderName,
          onChanged: notifier.updateAccountHolderName,
          textInputAction: TextInputAction.next,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Account Holder Name',
            hint: 'As per bank records',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: bank.bankName,
          onChanged: notifier.updateBankName,
          textInputAction: TextInputAction.next,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Bank Name',
            hint: 'HDFC Bank, ICICI Bank, etc.',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: bank.accountNumber,
          onChanged: notifier.updateAccountNumber,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(20),
          ],
          textInputAction: TextInputAction.next,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Account Number',
            hint: '6-20 digit account number',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: bank.ifsc,
          onChanged: notifier.updateIfsc,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'IFSC Code',
            hint: 'e.g., HDFC0001234',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: bank.branch,
          onChanged: notifier.updateBranch,
          textInputAction: TextInputAction.done,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Branch (Optional)',
            hint: 'Branch name or city',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statusPill(
              label: bank.isVerified ? 'Verified' : 'Not verified',
              icon: bank.isVerified ? Icons.verified : Icons.account_balance,
              color: bank.isVerified
                  ? AppTheme.successGreen
                  : AppTheme.warningAmber,
            ),
            const Spacer(),
            FilledButton(
              onPressed: bank.isLoading
                  ? null
                  : notifier.verifyAndSaveBankDetails,
              child: bank.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & Verify'),
            ),
          ],
        ),
        if (bank.errorMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              bank.errorMessage!,
              style: const TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
        if (bank.successMessage != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              bank.successMessage!,
              style: const TextStyle(color: AppTheme.successGreen),
            ),
          ),
        ],
      ],
    );
  }
}
