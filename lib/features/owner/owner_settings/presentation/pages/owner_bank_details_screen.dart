import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_bank_provider.dart';

class OwnerBankDetailsScreen extends ConsumerWidget {
  const OwnerBankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
  }) {
    final labelColor = theme.colorScheme.onPrimary.withValues(alpha: 0.85);
    final helperColor = theme.colorScheme.onPrimary.withValues(alpha: 0.6);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
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
