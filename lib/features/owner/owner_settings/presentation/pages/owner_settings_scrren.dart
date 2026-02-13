import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool enable2FA = false;
  bool notificationsEnabled = true;
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1000;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isDesktop ? 1100 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionCard(
                      theme,
                      "Profile Settings",
                      _profileSection(theme),
                    ),
                    const SizedBox(height: 32),
                    _sectionCard(
                      theme,
                      "Business Settings",
                      _businessSection(theme),
                    ),
                    const SizedBox(height: 32),
                    _sectionCard(
                      theme,
                      "Payment Configuration",
                      _paymentSection(theme),
                    ),
                    const SizedBox(height: 32),
                    _sectionCard(
                      theme,
                      "Security",
                      _securitySection(theme),
                    ),
                    const SizedBox(height: 32),
                    _sectionCard(
                      theme,
                      "System Preferences",
                      _systemSection(theme),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // SECTION WRAPPER
  // ==========================================================

  Widget _sectionCard(
      ThemeData theme, String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  // ==========================================================
  // PROFILE
  // ==========================================================

  Widget _profileSection(ThemeData theme) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: "Full Name"),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(labelText: "Email"),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(labelText: "Phone"),
        ),
      ],
    );
  }

  // ==========================================================
  // BUSINESS
  // ==========================================================

  Widget _businessSection(ThemeData theme) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: "Business Name"),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(labelText: "GST Number"),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(labelText: "Business Address"),
        ),
      ],
    );
  }

  // ==========================================================
  // PAYMENT
  // ==========================================================

  Widget _paymentSection(ThemeData theme) {
    return Column(
      children: [
        TextField(
          decoration:
              const InputDecoration(labelText: "Default Payment Mode"),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration:
              const InputDecoration(labelText: "Late Fee Percentage"),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(labelText: "Rent Due Day"),
        ),
      ],
    );
  }

  // ==========================================================
  // SECURITY
  // ==========================================================

  Widget _securitySection(ThemeData theme) {
    return Column(
      children: [
        SwitchListTile(
          value: enable2FA,
          onChanged: (v) => setState(() => enable2FA = v),
          title: const Text("Enable Two-Factor Authentication"),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {},
          child: const Text("Change Password"),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {},
          child: const Text("Logout"),
        ),
      ],
    );
  }

  // ==========================================================
  // SYSTEM
  // ==========================================================

  Widget _systemSection(ThemeData theme) {
    return Column(
      children: [
        SwitchListTile(
          value: notificationsEnabled,
          onChanged: (v) =>
              setState(() => notificationsEnabled = v),
          title: const Text("Enable Notifications"),
        ),
        SwitchListTile(
          value: darkMode,
          onChanged: (v) => setState(() => darkMode = v),
          title: const Text("Dark Mode"),
        ),
      ],
    );
  }
}