import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(theme, 'FAQs'),
          const SizedBox(height: 8),
          _faqTile('How do I add a tenant?'),
          _faqTile('How do I mark a payment as paid?'),
          _faqTile('How do I generate reports?'),
          const SizedBox(height: 24),
          _sectionTitle(theme, 'Contact Support'),
          const SizedBox(height: 8),
          _supportTile(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: 'support@rentdone.app',
          ),
          _supportTile(
            icon: Icons.phone_outlined,
            title: 'Phone',
            subtitle: '+91 90000 00000',
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
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
}
