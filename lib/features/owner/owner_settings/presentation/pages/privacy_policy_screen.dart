import 'package:flutter/material.dart';
import 'package:rentdone/core/config/legal_policy_config.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static final Uri _websiteUri = Uri.parse(LegalPolicyConfig.websiteUrl);
  static final Uri _emailUri = Uri.parse(
    'mailto:${LegalPolicyConfig.supportEmail}',
  );
  static final Uri _policyUri = Uri.parse(LegalPolicyConfig.privacyPolicyUrl);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text('Privacy Policy for RentDone', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Last updated: April 5, 2026',
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'What We Collect',
              bullets: const [
                'Account data: name, email, phone, and profile photo.',
                'Auth and session data to secure sign-in and account access.',
                'Payment transaction metadata for billing, reconciliation, and fraud checks.',
                'Diagnostics and analytics data to improve app performance and reliability.',
                'Optional approximate location when you grant permission.',
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'How We Use Data',
              bullets: const [
                'To provide rent management, payment, and notification features.',
                'To protect accounts and prevent abuse, fraud, and unauthorized access.',
                'To maintain legal and compliance records where required by law.',
                'To improve app quality, reliability, and user experience.',
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Third-Party Services',
              bullets: const [
                'Firebase (authentication, database, storage, analytics, crash reporting).',
                'Razorpay and Stripe (payments).',
                'Google AdMob (ads and ad measurement).',
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Your Rights',
              bullets: const [
                'You can request access, correction, or deletion of personal data.',
                'You can revoke optional permissions (such as location) in device settings.',
                'You can contact support for data privacy requests and clarifications.',
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact and Full Policy',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openUri(context, _policyUri),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Open Full Policy'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openUri(context, _websiteUri),
                          icon: const Icon(Icons.language_rounded),
                          label: const Text('Visit Website'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openUri(context, _emailUri),
                          icon: const Icon(Icons.mail_outline_rounded),
                          label: const Text('Email Support'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUri(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link right now.')),
      );
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $bullet', style: textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
