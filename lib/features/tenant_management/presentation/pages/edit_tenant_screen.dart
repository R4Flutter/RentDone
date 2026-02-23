import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant_management/domain/entities/tenant_entity.dart';
import 'package:rentdone/features/tenant_management/domain/usecases/validators.dart';
import 'package:rentdone/features/tenant_management/presentation/providers/tenant_providers.dart';
import 'package:rentdone/features/tenant_management/data/services/cloudinary_service.dart';

class EditTenantScreen extends ConsumerStatefulWidget {
  final String tenantId;

  const EditTenantScreen({Key? key, required this.tenantId}) : super(key: key);

  @override
  ConsumerState<EditTenantScreen> createState() => _EditTenantScreenState();
}

class _EditTenantScreenState extends ConsumerState<EditTenantScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _rentAmountController;
  late TextEditingController _securityDepositController;
  late TextEditingController _rentDueDateController;
  late TextEditingController _upiIdController;
  late TextEditingController _notesController;

  File? _newIdProofFile;
  File? _newAgreementFile;

  DateTime? _leaseEndDate;
  String _selectedPaymentMode = 'UPI';
  String _selectedIdProofType = 'aadhar';

  final Map<String, String> _fieldErrors = {};
  bool _isLoading = false;
  String? _uploadError;
  TenantEntity? _tenant;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _rentAmountController = TextEditingController();
    _securityDepositController = TextEditingController();
    _rentDueDateController = TextEditingController();
    _upiIdController = TextEditingController();
    _notesController = TextEditingController();

    // Load tenant data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTenantData();
    });
  }

  void _loadTenantData() {
    final tenantAsync = ref.watch(tenantProvider(widget.tenantId));
    tenantAsync.whenData((tenant) {
      if (tenant != null && mounted) {
        setState(() {
          _tenant = tenant;
          _phoneController.text = tenant.phone;
          _emailController.text = tenant.email ?? '';
          _rentAmountController.text = tenant.rentAmount.toString();
          _securityDepositController.text = tenant.securityDeposit.toString();
          _rentDueDateController.text = tenant.rentDueDate.toString();
          _upiIdController.text = tenant.upiId ?? '';
          _notesController.text = tenant.notes ?? '';
          _leaseEndDate = tenant.leaseEndDate;
          _selectedPaymentMode = tenant.paymentMode;
          _selectedIdProofType = tenant.idProofType ?? 'aadhar';
        });
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _rentAmountController.dispose();
    _securityDepositController.dispose();
    _rentDueDateController.dispose();
    _upiIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument({required String type}) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          if (type == 'idProof') {
            _newIdProofFile = File(result.files.single.path!);
          } else if (type == 'agreement') {
            _newAgreementFile = File(result.files.single.path!);
          }
          _uploadError = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick document: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _leaseEndDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _leaseEndDate = picked;
        _fieldErrors.remove('leaseEndDate');
      });
    }
  }

  void _validateForm() {
    setState(() {
      _fieldErrors.clear();

      // Validate phone
      final phoneError = TenantValidator.validatePhone(_phoneController.text);
      if (phoneError != null) {
        _fieldErrors['phone'] = phoneError;
      }

      // Validate email if provided
      final emailError = TenantValidator.validateEmail(
        _emailController.text.isEmpty ? null : _emailController.text,
      );
      if (emailError != null) {
        _fieldErrors['email'] = emailError;
      }

      // Validate rent amount
      final rentError = TenantValidator.validateRentAmount(
        int.tryParse(_rentAmountController.text),
      );
      if (rentError != null) {
        _fieldErrors['rentAmount'] = rentError;
      }

      // Validate security deposit
      final int? deposit = int.tryParse(_securityDepositController.text);
      if (deposit == null || deposit < 0) {
        _fieldErrors['securityDeposit'] = 'Enter valid deposit amount';
      }

      // Validate lease end date
      if (_leaseEndDate == null) {
        _fieldErrors['leaseEndDate'] = 'Please select lease end date';
      }

      // Validate rent due date
      final int? rentDueDay = int.tryParse(_rentDueDateController.text);
      final dueError = TenantValidator.validateRentDueDay(rentDueDay);
      if (dueError != null) {
        _fieldErrors['rentDueDate'] = dueError;
      }

      // Validate UPI if selected
      if (_selectedPaymentMode == 'UPI') {
        final upiError = TenantValidator.validateUpiId(
          _upiIdController.text,
          _selectedPaymentMode,
        );
        if (upiError != null) {
          _fieldErrors['upiId'] = upiError;
        }
      }
    });
  }

  Future<void> _submitForm() async {
    _validateForm();

    if (_fieldErrors.isNotEmpty) {
      return;
    }

    if (_tenant == null) return;

    setState(() {
      _isLoading = true;
      _uploadError = null;
    });

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);

      // Upload new documents if selected
      String idProofUrl = _tenant!.idProofUrl ?? '';
      String agreementUrl = _tenant!.agreementUrl ?? '';

      if (_newIdProofFile != null) {
        idProofUrl = await cloudinary.uploadIdProof(
          documentFile: _newIdProofFile!,
          tenantId: widget.tenantId,
          idType: _selectedIdProofType,
        );
      }

      if (_newAgreementFile != null) {
        agreementUrl = await cloudinary.uploadAgreement(
          documentFile: _newAgreementFile!,
          tenantId: widget.tenantId,
        );
      }

      // Create updated tenant entity
      final updatedTenant = _tenant!.copyWith(
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        rentAmount: int.parse(_rentAmountController.text),
        securityDeposit: int.parse(_securityDepositController.text),
        leaseEndDate: _leaseEndDate,
        rentDueDate: int.parse(_rentDueDateController.text),
        paymentMode: _selectedPaymentMode,
        upiId: _selectedPaymentMode == 'UPI' ? _upiIdController.text : null,
        idProofType: _selectedIdProofType,
        idProofUrl: idProofUrl,
        agreementUrl: agreementUrl,
        notes: _notesController.text,
        updatedAt: DateTime.now(),
      );

      // Update tenant via provider
      await ref
          .read(tenantNotifierProvider.notifier)
          .updateTenant(updatedTenant);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenant updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _uploadError = e.toString();
        _isLoading = false;
      });
      _showError(_uploadError!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(tenantProvider(widget.tenantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tenant'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'back') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'back',
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Back'),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert, color: Colors.white),
            ),
          ),
        ],
      ),
      body: tenantAsync.when(
        data: (tenant) {
          if (tenant == null) {
            return const Center(child: Text('Tenant not found'));
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Read-only information
                  _buildReadOnlySection(tenant),
                  const SizedBox(height: 24),

                  // Editable information
                  _buildSectionTitle('Edit Tenant Information'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter phone number',
                    keyboardType: TextInputType.phone,
                    error: _fieldErrors['phone'],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email (Optional)',
                    hint: 'Enter email address',
                    keyboardType: TextInputType.emailAddress,
                    error: _fieldErrors['email'],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _rentAmountController,
                    label: 'Monthly Rent Amount',
                    hint: 'Enter rent amount',
                    keyboardType: TextInputType.number,
                    error: _fieldErrors['rentAmount'],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _securityDepositController,
                    label: 'Security Deposit',
                    hint: 'Enter deposit amount',
                    keyboardType: TextInputType.number,
                    error: _fieldErrors['securityDeposit'],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _rentDueDateController,
                    label: 'Rent Due Date (Day of Month)',
                    hint: 'e.g., 1, 15, 30',
                    keyboardType: TextInputType.number,
                    error: _fieldErrors['rentDueDate'],
                  ),
                  const SizedBox(height: 12),
                  _buildDateField(
                    label: 'Lease End Date',
                    value: _leaseEndDate,
                    onTap: _selectDate,
                    error: _fieldErrors['leaseEndDate'],
                  ),
                  const SizedBox(height: 24),

                  // Documents
                  _buildSectionTitle('Update Documents'),
                  const SizedBox(height: 12),
                  _buildDocumentPreview(
                    title: 'Current ID Proof',
                    url: tenant.idProofUrl,
                    newFile: _newIdProofFile,
                    onPickNew: () => _pickDocument(type: 'idProof'),
                  ),
                  const SizedBox(height: 12),
                  _buildDocumentPreview(
                    title: 'Current Lease Agreement',
                    url: tenant.agreementUrl,
                    newFile: _newAgreementFile,
                    onPickNew: () => _pickDocument(type: 'agreement'),
                  ),
                  const SizedBox(height: 24),

                  // Notes
                  _buildSectionTitle('Additional Notes'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hint: 'Add any additional notes',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildReadOnlySection(TenantEntity tenant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Immutable Information (Cannot be changed)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          _buildReadOnlyField('Full Name', tenant.fullName),
          const SizedBox(height: 8),
          _buildReadOnlyField('Room Number', tenant.roomNumber),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            'Lease Start Date',
            DateFormat('MMM dd, yyyy').format(tenant.leaseStartDate),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyField(
            'Created Date',
            DateFormat('MMM dd, yyyy').format(tenant.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.nearBlack,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.nearBlack,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? Colors.red : Colors.transparent,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.nearBlack,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error != null ? Colors.red : Colors.transparent,
              ),
            ),
            child: Text(
              value != null
                  ? DateFormat('MMM dd, yyyy').format(value)
                  : 'Select date',
              style: TextStyle(
                fontSize: 14,
                color: value != null ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentPreview({
    required String title,
    required String? url,
    required File? newFile,
    required VoidCallback onPickNew,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.nearBlack,
          ),
        ),
        const SizedBox(height: 6),
        if (url != null && url.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.file_present, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Document uploaded',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Tap button below to replace',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (newFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      newFile.path.split('/').last,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPickNew,
            icon: const Icon(Icons.upload_file),
            label: Text(
              newFile != null ? 'Change Document' : 'Upload Document',
            ),
          ),
        ),
      ],
    );
  }
}
