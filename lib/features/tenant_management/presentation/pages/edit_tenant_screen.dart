import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant_management/domain/entities/tenant_entity.dart';
import 'package:rentdone/features/tenant_management/domain/usecases/validators.dart';
import 'package:rentdone/features/tenant_management/presentation/providers/tenant_providers.dart';
import 'package:rentdone/features/tenant_management/data/services/firebase_tenant_storage_service.dart';

class EditTenantScreen extends ConsumerStatefulWidget {
  final String tenantId;

  const EditTenantScreen({super.key, required this.tenantId});

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
  double? _uploadProgress;
  TenantEntity? _tenant;
  ProviderSubscription<AsyncValue<TenantEntity?>>? _tenantSubscription;

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
      if (!mounted) return;

      _tenantSubscription = ref.listenManual<AsyncValue<TenantEntity?>>(
        tenantProvider(widget.tenantId),
        (previous, next) {
          next.whenData((tenant) {
            if (tenant == null || !mounted) return;
            setState(() {
              _tenant = tenant;
              _phoneController.text = tenant.phone;
              _emailController.text = tenant.email ?? '';
              _rentAmountController.text = tenant.rentAmount.toString();
              _securityDepositController.text = tenant.securityDeposit
                  .toString();
              _rentDueDateController.text = tenant.rentDueDate.toString();
              _upiIdController.text = tenant.upiId ?? '';
              _notesController.text = tenant.notes ?? '';
              _leaseEndDate = tenant.leaseEndDate;
              _selectedPaymentMode = tenant.paymentMode;
              _selectedIdProofType = tenant.idProofType ?? 'aadhar';
            });
          });
        },
      );

      final initialTenant = ref.read(tenantProvider(widget.tenantId));
      initialTenant.whenData((tenant) {
        if (tenant == null || !mounted) return;
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
      });
    });
  }

  @override
  void dispose() {
    _tenantSubscription?.close();
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
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
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
      _uploadProgress = 0;
    });

    try {
      final storageService = ref.read(firebaseTenantStorageServiceProvider);
      final userId = _tenant?.ownerId;

      // Upload new documents if selected
      String idProofUrl = _tenant!.idProofUrl ?? '';
      String agreementUrl = _tenant!.agreementUrl ?? '';

      if (_newIdProofFile != null) {
        idProofUrl = await storageService.uploadIdProof(
          documentFile: _newIdProofFile!,
          tenantId: widget.tenantId,
          idType: _selectedIdProofType,
          userId: userId,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
      }

      if (_newAgreementFile != null) {
        agreementUrl = await storageService.uploadAgreement(
          documentFile: _newAgreementFile!,
          tenantId: widget.tenantId,
          userId: userId,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = progress;
            });
          },
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
          backgroundColor: AppTheme.successGreen,
        ),
      );

      // Navigate back
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError = _friendlyUploadError(e);
        _isLoading = false;
        _uploadProgress = null;
      });
      _showError(_uploadError!);
    }
  }

  String _friendlyUploadError(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('storage bucket not found')) {
      return 'Firebase Storage is not set up for this project. Open Firebase Console > Build > Storage > Get started, then retry.';
    }
    if (lower.contains('upload timed out')) {
      return 'Upload timed out. Check internet connection and try again.';
    }
    if (lower.contains('permission-denied') ||
        lower.contains('permission denied')) {
      return 'Upload permission denied. Sign in again and verify Storage rules.';
    }
    if (lower.contains('image could not be compressed to 200kb')) {
      return 'Image must be 200KB or smaller after compression. Use a lower-resolution image and retry.';
    }
    if (lower.contains('pdf must be 500kb or below')) {
      return 'PDF must be 500KB or below. Please reduce PDF size and retry.';
    }
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              PopupMenuItem<String>(
                value: 'back',
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: scheme.onSurface),
                    SizedBox(width: 12),
                    Text('Back'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.more_vert, color: scheme.onPrimary),
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

                  if (_isLoading && _uploadProgress != null) ...[
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      'Uploading ${(100 * _uploadProgress!).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        disabledBackgroundColor: scheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scheme.onPrimary,
                                ),
                              ),
                            )
                          : Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimary,
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
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Immutable Information (Cannot be changed)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
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
            fillColor: scheme.onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? scheme.error : AppColors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? scheme.error : AppColors.transparent,
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
              style: TextStyle(fontSize: 12, color: scheme.error),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error != null ? scheme.error : AppColors.transparent,
              ),
            ),
            child: Text(
              value != null
                  ? DateFormat('MMM dd, yyyy').format(value)
                  : 'Select date',
              style: TextStyle(
                fontSize: 14,
                color: value != null
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error,
              style: TextStyle(fontSize: 12, color: scheme.error),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        if (url != null && url.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.file_present,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
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
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.successGreen.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successGreen),
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
