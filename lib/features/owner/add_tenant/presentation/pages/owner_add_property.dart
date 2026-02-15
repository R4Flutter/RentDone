import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/providers/property_tenant_provider.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';
import 'package:uuid/uuid.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';

class AddTenantScreen extends ConsumerStatefulWidget {
  final String? propertyId;
  final String? roomId;

  const AddTenantScreen({super.key, this.propertyId, this.roomId});

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  int step = 0;

  // Controllers
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final rentCtrl = TextEditingController();
  final depositCtrl = TextEditingController();
  final incomeCtrl = TextEditingController();
  final emergencyNameCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();

  // State
  DateTime moveInDate = DateTime.now();
  bool policeVerified = false;
  bool backgroundChecked = false;
  late String? selectedPropertyId;
  late String? selectedRoomId;

  @override
  void initState() {
    super.initState();
    // Pre-populate if property and room are passed
    selectedPropertyId =
        (widget.propertyId == null || widget.propertyId!.isEmpty)
        ? null
        : widget.propertyId;
    selectedRoomId = (widget.roomId == null || widget.roomId!.isEmpty)
        ? null
        : widget.roomId;
    // If both are provided, skip to personal info step
    if (selectedPropertyId != null && selectedRoomId != null) {
      step = 1;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    rentCtrl.dispose();
    depositCtrl.dispose();
    incomeCtrl.dispose();
    emergencyNameCtrl.dispose();
    emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Add Tenant")),
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
                      _progressIndicator(theme),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildStepContent(step, theme),
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
                              onPressed: step == 4 ? _save : _next,
                              child: Text(
                                step == 4 ? "Save Tenant" : "Continue",
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

  // ===== PROGRESS INDICATOR =====
  Widget _progressIndicator(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LinearProgressIndicator(
        value: (step + 1) / 5,
        minHeight: 8,
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      ),
    );
  }

  // ===== STEP BUILDER =====
  Widget _buildStepContent(int step, ThemeData theme) {
    switch (step) {
      case 0:
        return _propertySelectionStep(theme);
      case 1:
        return _personalStep(theme);
      case 2:
        return _financialStep(theme);
      case 3:
        return _verificationStep(theme);
      default:
        return _reviewStep(theme);
    }
  }

  // ===== PROPERTY SELECTION STEP =====
  Widget _propertySelectionStep(ThemeData theme) {
    return _premiumCard(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Property & Room", style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          ref
              .watch(allPropertiesProvider)
              .when(
                data: (properties) {
                  if (properties.isEmpty) {
                    return Center(
                      child: Text(
                        "No properties available. Create one first.",
                        style: theme.textTheme.bodyLarge,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Property", style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedPropertyId,
                        decoration: InputDecoration(
                          hintText: "Select a property",
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: properties
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPropertyId = value;
                            selectedRoomId = null;
                          });
                        },
                        validator: (value) =>
                            value == null ? "Select a property" : null,
                      ),
                      const SizedBox(height: 20),
                      if (selectedPropertyId != null) ...[
                        Text("Room/Unit", style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        ..._buildRoomSelection(theme, properties),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stk) =>
                    Center(child: Text("Error: ${err.toString()}")),
              ),
        ],
      ),
    );
  }

  List<Widget> _buildRoomSelection(ThemeData theme, List<Property> properties) {
    final property = properties.firstWhere(
      (p) => p.id == selectedPropertyId,
      orElse: () => properties.first,
    );

    final vacantRooms = property.rooms.where((r) => !r.isOccupied).toList();

    if (vacantRooms.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Text(
            "No vacant rooms in this property",
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ];
    }

    return [
      DropdownButtonFormField<String>(
        value: selectedRoomId,
        decoration: InputDecoration(
          hintText: "Select a room",
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        items: vacantRooms
            .map(
              (r) => DropdownMenuItem(
                value: r.id,
                child: Text("${r.roomNumber} - ${r.name}"),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() => selectedRoomId = value);
        },
        validator: (value) => value == null ? "Select a room" : null,
      ),
    ];
  }

  // ===== PERSONAL STEP =====
  Widget _personalStep(ThemeData theme) {
    return _premiumCard(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Personal Information", style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          _inputField("Full Name", nameCtrl),
          const SizedBox(height: 16),
          _inputField("Phone Number", phoneCtrl, keyboard: TextInputType.phone),
          const SizedBox(height: 16),
          _inputField("Email Address", emailCtrl),
          const SizedBox(height: 16),
          _dateTile(theme),
        ],
      ),
    );
  }

  // ===== FINANCIAL STEP =====
  Widget _financialStep(ThemeData theme) {
    return _premiumCard(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Financial Details", style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          _inputField("Monthly Rent", rentCtrl, keyboard: TextInputType.number),
          const SizedBox(height: 16),
          _inputField(
            "Security Deposit",
            depositCtrl,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _inputField(
            "Monthly Income",
            incomeCtrl,
            keyboard: TextInputType.number,
          ),
        ],
      ),
    );
  }

  // ===== VERIFICATION STEP =====
  Widget _verificationStep(ThemeData theme) {
    return _premiumCard(
      theme,
      Column(
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
          _inputField(
            "Emergency Contact Phone",
            emergencyPhoneCtrl,
            keyboard: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  // ===== REVIEW STEP =====
  Widget _reviewStep(ThemeData theme) {
    return _premiumCard(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Review Details", style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          _reviewItem(theme, "Name", nameCtrl.text),
          _reviewItem(theme, "Phone", phoneCtrl.text),
          _reviewItem(theme, "Email", emailCtrl.text),
          _reviewItem(theme, "Rent", "₹${rentCtrl.text}"),
          _reviewItem(
            theme,
            "Move-in",
            "${moveInDate.day}/${moveInDate.month}/${moveInDate.year}",
          ),
          const SizedBox(height: 24),
          Text(
            "Click 'Save Tenant' to proceed",
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===== PREMIUM CARD =====
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

  // ===== INPUT FIELD =====
  Widget _inputField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) => value?.isEmpty ?? true ? "Required" : null,
    );
  }

  // ===== DATE TILE =====
  Widget _dateTile(ThemeData theme) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: Colors.white.withValues(alpha: 0.08),
      title: const Text("Move-in Date"),
      subtitle: Text(
        "${moveInDate.day}-${moveInDate.month}-${moveInDate.year}",
      ),
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

  // ===== NAVIGATION =====
  void _next() {
    if (_formKey.currentState!.validate()) {
      setState(() => step++);
    }
  }

  void _back() {
    if (step > 0) setState(() => step--);
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedPropertyId == null || selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a property and room"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate numeric fields
    try {
      int.parse(rentCtrl.text);
      int.parse(depositCtrl.text);
      if (incomeCtrl.text.isNotEmpty) {
        double.parse(incomeCtrl.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please enter valid amounts"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final tenant = Tenant(
      id: const Uuid().v4(),
      fullName: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      tenantType: "Individual",
      propertyId: selectedPropertyId!,
      roomId: selectedRoomId!,
      moveInDate: moveInDate,
      rentAmount: int.parse(rentCtrl.text),
      securityDeposit: int.parse(depositCtrl.text),
      rentFrequency: "Monthly",
      rentDueDay: 1,
      paymentMode: "UPI",
      lateFinePercentage: 0,
      noticePeriodDays: 30,
      maintenanceCharge: 0,
      policeVerified: policeVerified,
      backgroundChecked: backgroundChecked,
      isActive: true,
      createdAt: DateTime.now(),
      monthlyIncome: incomeCtrl.text.isNotEmpty
          ? double.parse(incomeCtrl.text)
          : null,
      emergencyName: emergencyNameCtrl.text.trim(),
      emergencyPhone: emergencyPhoneCtrl.text.trim(),
    );

    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // Add tenant to database
      await ref.read(addTenantNotifierProvider.notifier).addTenant(tenant);

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message and pop
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tenant allocated successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Pop back to property detail screen
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog if open
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
