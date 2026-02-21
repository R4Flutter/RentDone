import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/add_tenant/domain/usecases/tenant_input_validator.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/providers/add_tenant_provider.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/providers/document_upload_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_upi_provider.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/providers/property_tenant_provider.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:rentdone/app/app_theme.dart';

class AddTenantScreen extends ConsumerStatefulWidget {
  final String? propertyId;
  final String? roomId;

  const AddTenantScreen({super.key, this.propertyId, this.roomId});

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _validator = TenantInputValidator();
  int step = 0;

  // Controllers
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final whatsappCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final rentCtrl = TextEditingController();
  final depositCtrl = TextEditingController();
  final rentDueDayCtrl = TextEditingController(text: '1');
  final incomeCtrl = TextEditingController();
  final emergencyNameCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();

  // State
  DateTime moveInDate = DateTime.now();
  bool policeVerified = false;
  bool backgroundChecked = false;
  late String? selectedPropertyId;
  late String? selectedRoomId;
  late final String tenantDraftId;

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
    tenantDraftId = const Uuid().v4();
    // If both are provided, skip to personal info step
    if (selectedPropertyId != null && selectedRoomId != null) {
      step = 1;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    whatsappCtrl.dispose();
    emailCtrl.dispose();
    rentCtrl.dispose();
    depositCtrl.dispose();
    rentDueDayCtrl.dispose();
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
                              onPressed: step == 5 ? _save : _next,
                              child: Text(
                                step == 5 ? "Save Tenant" : "Continue",
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
        value: (step + 1) / 6,
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
      case 4:
        return _documentsStep(theme);
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
                        initialValue: selectedPropertyId,
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
        initialValue: selectedRoomId,
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
          _inputField(
            "Full Name",
            nameCtrl,
            validator: _validator.validateName,
          ),
          const SizedBox(height: 16),
          _inputField(
            "Phone Number",
            phoneCtrl,
            keyboard: TextInputType.phone,
            validator: _validator.validatePhone,
          ),
          const SizedBox(height: 16),
          _inputField(
            "WhatsApp Number",
            whatsappCtrl,
            keyboard: TextInputType.phone,
            validator: _validator.validatePhone,
          ),
          const SizedBox(height: 16),
          _inputField(
            "Email Address",
            emailCtrl,
            validator: _validator.validateEmail,
          ),
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
          _inputField(
            "Monthly Rent",
            rentCtrl,
            keyboard: TextInputType.number,
            validator: _validator.validateRentAmount,
          ),
          const SizedBox(height: 16),
          _inputField(
            "Security Deposit",
            depositCtrl,
            keyboard: TextInputType.number,
            validator: _validator.validateSecurityDeposit,
          ),
          const SizedBox(height: 16),
          _inputField(
            "Monthly Income",
            incomeCtrl,
            keyboard: TextInputType.number,
            validator: _validator.validateMonthlyIncome,
          ),
          const SizedBox(height: 16),
          _inputField(
            "Rent Due Day (1-31)",
            rentDueDayCtrl,
            keyboard: TextInputType.number,
            validator: _validator.validateRentDueDay,
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
          _inputField(
            "Emergency Contact Name",
            emergencyNameCtrl,
            validator: _validator.validateEmergencyName,
          ),
          const SizedBox(height: 16),
          _inputField(
            "Emergency Contact Phone",
            emergencyPhoneCtrl,
            keyboard: TextInputType.phone,
            validator: _validator.validateEmergencyPhone,
          ),
        ],
      ),
    );
  }

  // ===== DOCUMENTS STEP =====
  Widget _documentsStep(ThemeData theme) {
    final documentUrls = ref.watch(addTenantNotifierProvider).documentUrls;
    final uploadState = ref.watch(documentUploadProvider);

    return _premiumCard(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Upload Documents", style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            "Upload at least 2 documents for verification (ID, Address Proof, etc.)",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (uploadState.status == DocumentUploadStatus.loading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: uploadState.progress),
            const SizedBox(height: 8),
            Text(
              'Uploading ${(uploadState.progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          if (documentUrls.isNotEmpty) ...[
            Text(
              "Uploaded Documents (${documentUrls.length})",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...documentUrls.map(
              (url) => _documentTile(theme, url, documentUrls.indexOf(url)),
            ),
            const SizedBox(height: 24),
          ],
          ElevatedButton.icon(
            onPressed: _pickDocument,
            icon: const Icon(Icons.upload_file),
            label: const Text("Add Document"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentTile(ThemeData theme, String url, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text("Document ${index + 1}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            ref.read(addTenantNotifierProvider.notifier).removeDocument(index);
            ref.read(documentUploadProvider.notifier).removeUploadedUrl(url);
          },
        ),
        onTap: () => _viewDocument(url),
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
          _reviewItem(theme, "Rent", "Rs ${rentCtrl.text}"),
          _reviewItem(theme, "Rent Due Day", rentDueDayCtrl.text),
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
    String? Function(String?)? validator,
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
      validator:
          validator ?? ((value) => value?.isEmpty ?? true ? "Required" : null),
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

    // Validate documents
    final documentUrls = ref.read(addTenantNotifierProvider).documentUrls;
    final docError = _validator.validateDocuments(documentUrls);
    if (docError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(docError), backgroundColor: Colors.red),
      );
      return;
    }

    final verifiedUpiId = await ref
        .read(ownerUpiProvider.notifier)
        .getVerifiedUpiId();
    if (verifiedUpiId == null || verifiedUpiId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please set and verify owner UPI once in Settings before adding tenants.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tenant = Tenant(
      id: tenantDraftId,
      ownerId: FirebaseAuth.instance.currentUser?.uid,
      fullName: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      whatsappPhone: whatsappCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      tenantType: "Individual",
      propertyId: selectedPropertyId!,
      roomId: selectedRoomId!,
      moveInDate: moveInDate,
      rentAmount: int.parse(rentCtrl.text),
      securityDeposit: int.parse(depositCtrl.text),
      rentFrequency: "Monthly",
      rentDueDay: int.parse(rentDueDayCtrl.text),
      paymentMode: "UPI",
      upiId: verifiedUpiId,
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
      documentUrls: documentUrls,
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
      await ref.read(addTenantNotifierProvider.notifier).submitTenant(tenant);

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Return to previous screen immediately after save.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/owner/tenants/manage');
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog if open
      Navigator.of(context, rootNavigator: true).pop();

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

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not access selected file.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final file = File(selectedPath);

    // Verify file exists before uploading
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected file is no longer available.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final previousUrls = ref.read(documentUploadProvider).uploadedUrls;

    // Show upload progress in UI
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uploading document...'),
        duration: Duration(seconds: 30),
      ),
    );

    await ref
        .read(documentUploadProvider.notifier)
        .uploadTenantDocument(file, tenantDraftId);

    if (!mounted) return;

    // Clear the temporary progress message
    ScaffoldMessenger.of(context).clearSnackBars();

    final uploadState = ref.read(documentUploadProvider);
    if (uploadState.status == DocumentUploadStatus.success) {
      final newUrls = uploadState.uploadedUrls
          .where((url) => !previousUrls.contains(url))
          .toList();

      for (final url in newUrls) {
        ref.read(addTenantNotifierProvider.notifier).addDocument(url);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      ref.read(documentUploadProvider.notifier).clearTransientState();
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadState.errorMessage ?? 'Document upload failed.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    ref.read(documentUploadProvider.notifier).clearTransientState();
  }

  void _viewDocument(String url) {
    // For now, just show a snackbar. In production, open in browser or viewer
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document viewing not implemented yet')),
    );
  }
}
