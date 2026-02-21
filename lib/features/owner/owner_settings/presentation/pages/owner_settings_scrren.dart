import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_bank_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_settings_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_upi_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(ownerSettingsProvider);
    final notifier = ref.read(ownerSettingsProvider.notifier);
    final ownerUpi = ref.watch(ownerUpiProvider);
    final ownerUpiNotifier = ref.read(ownerUpiProvider.notifier);
    final ownerBank = ref.watch(ownerBankProvider);
    final ownerBankNotifier = ref.read(ownerBankProvider.notifier);
    final isDesktop = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1200 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pageHeader(theme),
                const SizedBox(height: 24),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _sectionCard(
                              theme,
                              icon: Icons.person_outline,
                              title: 'Profile',
                              subtitle: 'Your personal contact details.',
                              child: _profileSection(settings, notifier, theme),
                            ),
                            const SizedBox(height: 24),
                            _sectionCard(
                              theme,
                              icon: Icons.storefront,
                              title: 'Business',
                              subtitle: 'Billing and legal information.',
                              child: _businessSection(
                                settings,
                                notifier,
                                theme,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _sectionCard(
                              theme,
                              icon: Icons.payments_outlined,
                              title: 'Payments',
                              subtitle: 'Default modes and rent policies.',
                              child: _paymentSection(
                                settings,
                                notifier,
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
                              child: _bankSection(
                                ownerBank,
                                ownerBankNotifier,
                                theme,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sectionCard(
                              theme,
                              icon: Icons.shield_outlined,
                              title: 'Security',
                              subtitle: 'Protect your account access.',
                              child: _securitySection(
                                settings,
                                notifier,
                                theme,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _sectionCard(
                              theme,
                              icon: Icons.tune,
                              title: 'Preferences',
                              subtitle: 'Notifications and display.',
                              child: _systemSection(settings, notifier, theme),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _sectionCard(
                    theme,
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'Your personal contact details.',
                    child: _profileSection(settings, notifier, theme),
                  ),
                  const SizedBox(height: 24),
                  _sectionCard(
                    theme,
                    icon: Icons.storefront,
                    title: 'Business',
                    subtitle: 'Billing and legal information.',
                    child: _businessSection(settings, notifier, theme),
                  ),
                  const SizedBox(height: 24),
                  _sectionCard(
                    theme,
                    icon: Icons.payments_outlined,
                    title: 'Payments',
                    subtitle: 'Default modes and rent policies.',
                    child: _paymentSection(
                      settings,
                      notifier,
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
                    child: _bankSection(ownerBank, ownerBankNotifier, theme),
                  ),
                  const SizedBox(height: 24),
                  _sectionCard(
                    theme,
                    icon: Icons.shield_outlined,
                    title: 'Security',
                    subtitle: 'Protect your account access.',
                    child: _securitySection(settings, notifier, theme),
                  ),
                  const SizedBox(height: 24),
                  _sectionCard(
                    theme,
                    icon: Icons.tune,
                    title: 'Preferences',
                    subtitle: 'Notifications and display.',
                    child: _systemSection(settings, notifier, theme),
                  ),
                ],
                const SizedBox(height: 8),
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
              Text('Settings', style: theme.textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Your changes save automatically and apply across the app.',
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
    String? prefixText,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    final labelColor = theme.colorScheme.onPrimary.withValues(alpha: 0.85);
    final helperColor = theme.colorScheme.onPrimary.withValues(alpha: 0.6);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixText: prefixText,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
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

  Widget _profileSection(
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    return Column(
      children: [
        TextFormField(
          initialValue: settings.fullName,
          onChanged: notifier.updateFullName,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Full Name',
            hint: 'e.g., Aditi Sharma',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: settings.email,
          onChanged: notifier.updateEmail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Email',
            hint: 'you@company.com',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: settings.phone,
          onChanged: notifier.updatePhone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          autofillHints: const [AutofillHints.telephoneNumber],
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Phone',
            hint: '10-digit mobile number',
          ),
        ),
      ],
    );
  }

  Widget _businessSection(
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    return Column(
      children: [
        TextFormField(
          initialValue: settings.businessName,
          onChanged: notifier.updateBusinessName,
          textInputAction: TextInputAction.next,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Business Name',
            hint: 'RentDone Properties',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: settings.gstNumber,
          onChanged: notifier.updateGstNumber,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'GST Number',
            hint: 'Optional',
            helper: 'Use for invoices and tax reporting.',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: settings.businessAddress,
          onChanged: notifier.updateBusinessAddress,
          textInputAction: TextInputAction.done,
          maxLines: 2,
          style: textStyle,
          decoration: _fieldDecoration(
            theme,
            label: 'Business Address',
            hint: 'Street, city, state',
          ),
        ),
      ],
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
          value: effectiveMode,
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

  Widget _securitySection(
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
    );
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: settings.enable2FA,
          onChanged: notifier.setEnable2FA,
          title: Text('Enable Two-Factor Authentication', style: titleStyle),
          subtitle: Text(
            'Adds an extra verification step on login.',
            style: subtitleStyle,
          ),
          secondary: Icon(
            Icons.phonelink_lock,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.lock_reset),
          label: const Text('Change Password'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
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

  Widget _systemSection(
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
    );
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: settings.notificationsEnabled,
          onChanged: notifier.setNotificationsEnabled,
          title: Text('Enable Notifications', style: titleStyle),
          subtitle: Text(
            'Receive rent alerts and reminders.',
            style: subtitleStyle,
          ),
          secondary: Icon(
            Icons.notifications_active_outlined,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        SwitchListTile.adaptive(
          value: settings.darkMode,
          onChanged: notifier.setDarkMode,
          title: Text('Dark Mode', style: titleStyle),
          subtitle: Text('Use a darker color scheme.', style: subtitleStyle),
          secondary: Icon(
            Icons.dark_mode_outlined,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
