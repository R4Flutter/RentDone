import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant_management/domain/entities/tenant_entity.dart';
import 'package:rentdone/features/tenant_management/domain/usecases/validators.dart';
import 'package:rentdone/features/tenant_management/presentation/providers/tenant_providers.dart';
import 'package:rentdone/features/tenant_management/data/services/cloudinary_service.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class AddTenantScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const AddTenantScreen({super.key, required this.propertyId});

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _roomNumberController;
  late TextEditingController _rentAmountController;
  late TextEditingController _securityDepositController;
  late TextEditingController _rentDueDateController;
  late TextEditingController _upiIdController;
  late TextEditingController _notesController;

  File? _profileImage;
  File? _idProofFile;
  File? _agreementFile;

  DateTime? _leaseStartDate;
  DateTime? _leaseEndDate;
  String _selectedPaymentMode = 'UPI';
  String _selectedIdProofType = 'aadhar';
  String _selectedRentFrequency = 'monthly';

  final Map<String, String> _fieldErrors = {};
  bool _isLoading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _roomNumberController = TextEditingController();
    _rentAmountController = TextEditingController();
    _securityDepositController = TextEditingController();
    _rentDueDateController = TextEditingController();
    _upiIdController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _roomNumberController.dispose();
    _rentAmountController.dispose();
    _securityDepositController.dispose();
    _rentDueDateController.dispose();
    _upiIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _uploadError = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
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
            _idProofFile = File(result.files.single.path!);
          } else if (type == 'agreement') {
            _agreementFile = File(result.files.single.path!);
          }
          _uploadError = null;
        });
      }
    } catch (e) {
      _showError('Failed to pick document: $e');
    }
  }

  Future<void> _selectDate({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_leaseStartDate ?? DateTime.now())
          : (_leaseEndDate ?? DateTime.now().add(const Duration(days: 365))),
      firstDate: isStart ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _leaseStartDate = picked;
          _fieldErrors.remove('leaseStartDate');
        } else {
          _leaseEndDate = picked;
          _fieldErrors.remove('leaseEndDate');
        }
      });
    }
  }

  void _validateForm() {
    setState(() {
      _fieldErrors.clear();

      // Validate full name
      final fullNameError = TenantValidator.validateFullName(
        _fullNameController.text,
      );
      if (fullNameError != null) {
        _fieldErrors['fullName'] = fullNameError;
      }

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

      // Validate lease dates
      if (_leaseStartDate == null) {
        _fieldErrors['leaseStartDate'] = 'Please select lease start date';
      }
      if (_leaseEndDate == null) {
        _fieldErrors['leaseEndDate'] = 'Please select lease end date';
      }
      if (_leaseStartDate != null && _leaseEndDate != null) {
        final dateError = TenantValidator.validateLeaseDates(
          _leaseStartDate!,
          _leaseEndDate,
        );
        if (dateError != null) {
          _fieldErrors['leaseEndDate'] = dateError;
        }
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

      // Check documents
      if (_idProofFile == null) {
        _fieldErrors['idProof'] = 'Please upload ID proof';
      }
      if (_agreementFile == null) {
        _fieldErrors['agreement'] = 'Please upload lease agreement';
      }
    });
  }

  Future<void> _submitForm() async {
    _validateForm();

    if (_fieldErrors.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadError = null;
    });

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Upload documents
      String idProofUrl = '';
      String agreementUrl = '';

      if (_idProofFile != null) {
        idProofUrl = await cloudinary.uploadIdProof(
          documentFile: _idProofFile!,
          tenantId: '${DateTime.now().millisecondsSinceEpoch}',
          idType: _selectedIdProofType,
        );
      }

      if (_agreementFile != null) {
        agreementUrl = await cloudinary.uploadAgreement(
          documentFile: _agreementFile!,
          tenantId: '${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await cloudinary.uploadProfileImage(
          imageFile: _profileImage!,
          tenantId: '${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // Create tenant entity
      final tenant = TenantEntity(
        id: '', // Firebase will generate
        ownerId: userId,
        propertyId: widget.propertyId,
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        profileImageUrl: profileImageUrl,
        dateOfBirth: null,
        roomNumber: _roomNumberController.text,
        rentAmount: int.parse(_rentAmountController.text),
        securityDeposit: int.parse(_securityDepositController.text),
        leaseStartDate: _leaseStartDate!,
        leaseEndDate: _leaseEndDate,
        rentDueDate: int.parse(_rentDueDateController.text),
        rentFrequency: _selectedRentFrequency,
        paymentMode: _selectedPaymentMode,
        upiId: _selectedPaymentMode == 'UPI' ? _upiIdController.text : null,
        lateFinePercentage: 5.0,
        maintenanceCharge: 0.0,
        noticePeriodDays: 30,
        idProofType: _selectedIdProofType,
        idProofUrl: idProofUrl,
        agreementUrl: agreementUrl,
        additionalDocumentUrls: [],
        companyName: null,
        jobTitle: null,
        monthlyIncome: null,
        emergencyName: null,
        emergencyPhone: null,
        emergencyRelation: null,
        previousLandlordName: null,
        previousLandlordPhone: null,
        previousAddress: null,
        policeVerified: false,
        backgroundChecked: false,
        status: 'active',
        notes: _notesController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add tenant via provider
      await ref.read(tenantNotifierProvider.notifier).addTenant(tenant);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenant added successfully'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Tenant'),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image Section
              _buildSectionTitle('Profile Picture'),
              const SizedBox(height: 12),
              _buildImagePickerCard(),
              const SizedBox(height: 24),

              // Personal Information
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'Enter full name',
                error: _fieldErrors['fullName'],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Enter 10 digit phone number',
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
              const SizedBox(height: 24),

              // Rental Information
              _buildSectionTitle('Rental Information'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _roomNumberController,
                label: 'Room/Unit Number',
                hint: 'e.g., 101, A, etc',
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
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                label: 'Rent Frequency',
                value: _selectedRentFrequency,
                items: const ['monthly', 'quarterly', 'annual'],
                onChanged: (value) {
                  setState(() {
                    _selectedRentFrequency = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _rentDueDateController,
                label: 'Rent Due Date (Day of Month)',
                hint: 'e.g., 1, 15, 30',
                keyboardType: TextInputType.number,
                error: _fieldErrors['rentDueDate'],
              ),
              const SizedBox(height: 24),

              // Lease Dates
              _buildSectionTitle('Lease Information'),
              const SizedBox(height: 12),
              _buildDateField(
                label: 'Lease Start Date',
                value: _leaseStartDate,
                onTap: () => _selectDate(isStart: true),
                error: _fieldErrors['leaseStartDate'],
              ),
              const SizedBox(height: 12),
              _buildDateField(
                label: 'Lease End Date',
                value: _leaseEndDate,
                onTap: () => _selectDate(isStart: false),
                error: _fieldErrors['leaseEndDate'],
              ),
              const SizedBox(height: 24),

              // Payment Information
              _buildSectionTitle('Payment Information'),
              const SizedBox(height: 12),
              _buildDropdownField(
                label: 'Payment Mode',
                value: _selectedPaymentMode,
                items: const ['UPI', 'cash', 'bank_transfer', 'check'],
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMode = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_selectedPaymentMode == 'UPI')
                _buildTextField(
                  controller: _upiIdController,
                  label: 'UPI ID',
                  hint: 'e.g., name@upi',
                  error: _fieldErrors['upiId'],
                ),
              const SizedBox(height: 24),

              // Documents
              _buildSectionTitle('Documents'),
              const SizedBox(height: 12),
              _buildDropdownField(
                label: 'ID Proof Type',
                value: _selectedIdProofType,
                items: const ['aadhar', 'pan', 'passport', 'driving_license'],
                onChanged: (value) {
                  setState(() {
                    _selectedIdProofType = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildDocumentPickerCard(
                title: 'ID Proof',
                file: _idProofFile,
                onTap: () => _pickDocument(type: 'idProof'),
                error: _fieldErrors['idProof'],
              ),
              const SizedBox(height: 12),
              _buildDocumentPickerCard(
                title: 'Lease Agreement',
                file: _agreementFile,
                onTap: () => _pickDocument(type: 'agreement'),
                error: _fieldErrors['agreement'],
              ),
              const SizedBox(height: 24),

              // Additional Notes
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
                          'Add Tenant',
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
      ),
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
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

  Widget _buildImagePickerCard() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _profileImage == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select profile picture',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_profileImage!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDocumentPickerCard({
    required String title,
    required File? file,
    required VoidCallback onTap,
    String? error,
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: error != null ? Colors.red : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.file_present, color: Colors.grey[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file != null
                            ? file.path.split('/').last
                            : 'Select document',
                        style: TextStyle(
                          fontSize: 14,
                          color: file != null ? Colors.black : Colors.grey[600],
                          fontWeight: file != null ? FontWeight.w500 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (file != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Tap to replace',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  file != null ? Icons.check_circle : Icons.upload_file,
                  color: file != null ? Colors.green : Colors.grey[400],
                ),
              ],
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
}
