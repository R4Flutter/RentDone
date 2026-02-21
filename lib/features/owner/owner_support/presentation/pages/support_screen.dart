import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_support/presentation/providers/support_provider.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final content = ref.watch(supportContentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(theme, 'FAQs'),
          const SizedBox(height: 8),
          ...content.faqs.map((faq) => _faqTile(faq.question)),
          const SizedBox(height: 24),
          _sectionTitle(theme, 'Contact Support'),
          const SizedBox(height: 8),
          ...content.contacts.map(
            (contact) => _supportTile(
              icon: _iconForType(contact.type),
              title: contact.title,
              subtitle: contact.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _faqTile(String question) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(question),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }

  Widget _supportTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      default:
        return Icons.support_agent;
    }
  }
}
