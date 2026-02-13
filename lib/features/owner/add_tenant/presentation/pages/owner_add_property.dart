import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class AddTenantScreen extends StatefulWidget {
  const AddTenantScreen({super.key});

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends State<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  int step = 0;

  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final rentCtrl = TextEditingController();
  final depositCtrl = TextEditingController();
  final incomeCtrl = TextEditingController();
  final emergencyNameCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();

  DateTime moveInDate = DateTime.now();
  bool policeVerified = false;
  bool backgroundChecked = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
  

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Tenant"),
      ),
      body: LayoutBuilder(
  builder: (context, constraints) {
    final isDesktop = constraints.maxWidth >= 900;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 750 : double.infinity,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _progressIndicator(Theme.of(context)),
                const SizedBox(height: 32),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _premiumCard(
                    Theme.of(context),
                    _buildStepContent(step, Theme.of(context)),
                  ),
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    if (step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _back,
                          child: const Text("Back"),
                        ),
                      ),
                    if (step > 0) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: step == 3 ? _save : _next,
                        child: Text(
                          step == 3 ? "Save Tenant" : "Continue",
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
),
    );
  }

  // ==============================================================
  // PREMIUM PROGRESS BAR
  // ==============================================================

  Widget _progressIndicator(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        value: (step + 1) / 4,
        minHeight: 8,
        backgroundColor:
            theme.colorScheme.onSurface.withValues(alpha: 0.08),
      ),
    );
  }

  // ==============================================================
  // STEP BUILDER
  // ==============================================================

  Widget _buildStepContent(int step, ThemeData theme) {
    switch (step) {
      case 0:
        return _premiumCard(theme, _personalStep(theme));
      case 1:
        return _premiumCard(theme, _financialStep(theme));
      case 2:
        return _premiumCard(theme, _verificationStep(theme));
      default:
        return _premiumCard(theme, _reviewStep(theme));
    }
  }

  // ==============================================================
  // PREMIUM CARD (30% BLUE SURFACE)
  // ==============================================================

  Widget _premiumCard(ThemeData theme, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  // ==============================================================
  // PERSONAL STEP
  // ==============================================================

  Widget _personalStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Personal Information", style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        _inputField("Full Name", nameCtrl),
        const SizedBox(height: 16),
        _inputField("Phone Number", phoneCtrl,
            keyboard: TextInputType.phone),
        const SizedBox(height: 16),
        _inputField("Email Address", emailCtrl),
        const SizedBox(height: 16),
        _dateTile(theme),
      ],
    );
  }

  Widget _financialStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Financial Details", style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        _inputField("Monthly Rent", rentCtrl,
            keyboard: TextInputType.number),
        const SizedBox(height: 16),
        _inputField("Security Deposit", depositCtrl,
            keyboard: TextInputType.number),
        const SizedBox(height: 16),
        _inputField("Monthly Income", incomeCtrl,
            keyboard: TextInputType.number),
      ],
    );
  }

  Widget _verificationStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Verification & Safety", style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        SwitchListTile(
          value: policeVerified,
          onChanged: (v) => setState(() => policeVerified = v),
          title: const Text("Police Verified"),
        ),
        SwitchListTile(
          value: backgroundChecked,
          onChanged: (v) => setState(() => backgroundChecked = v),
          title: const Text("Background Checked"),
        ),
        const SizedBox(height: 16),
        _inputField("Emergency Contact Name", emergencyNameCtrl),
        const SizedBox(height: 16),
        _inputField("Emergency Contact Phone", emergencyPhoneCtrl,
            keyboard: TextInputType.phone),
      ],
    );
  }

  Widget _reviewStep(ThemeData theme) {
    return Center(
      child: Text(
        "Review details and click Save Tenant.",
        style: theme.textTheme.bodyLarge,
      ),
    );
  }

  // ==============================================================
  // REUSABLE INPUT FIELD
  // ==============================================================

  Widget _inputField(String label, TextEditingController controller,
      {TextInputType? keyboard}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor:
            Colors.white.withValues(alpha: 0.08), // subtle premium field
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dateTile(ThemeData theme) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      tileColor: Colors.white.withValues(alpha: 0.08),
      title: const Text("Move-in Date"),
      subtitle:
          Text("${moveInDate.day}-${moveInDate.month}-${moveInDate.year}"),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          initialDate: moveInDate,
        );
        if (picked != null) {
          setState(() => moveInDate = picked);
        }
      },
    );
  }

  void _next() {
    if (step < 3) setState(() => step++);
  }

  void _back() {
    if (step > 0) setState(() => step--);
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Tenant Saved (UI Only)")),
    );
  }
}