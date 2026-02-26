import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant_management/domain/entities/payment_entity.dart';
import 'package:rentdone/features/tenant_management/domain/usecases/validators.dart';
import 'package:rentdone/features/tenant_management/presentation/providers/payment_providers.dart';
import 'package:rentdone/features/tenant_management/presentation/providers/tenant_providers.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String tenantId;
  final String propertyId;

  const RecordPaymentScreen({
    super.key,
    required this.tenantId,
    required this.propertyId,
  });

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  late TextEditingController _amountController;
  late TextEditingController _referenceIdController;
  late TextEditingController _notesController;

  String _selectedMonth = _getCurrentMonth();
  String _selectedPaymentMethod = 'UPI';
  DateTime? _paymentDate;

  final Map<String, String> _fieldErrors = {};
  bool _isLoading = false;
  String? _submitError;

  static String _getCurrentMonth() {
    final now = DateTime.now();
    return DateFormat('MMM yyyy').format(now);
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _referenceIdController = TextEditingController();
    _notesController = TextEditingController();
    _paymentDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectPaymentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
        _fieldErrors.remove('paymentDate');
      });
    }
  }

  void _selectMonth() {
    showDialog(
      context: context,
      builder: (context) => _buildMonthPickerDialog(),
    );
  }

  Widget _buildMonthPickerDialog() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final years = List.generate(5, (i) => DateTime.now().year - 2 + i);

    return AlertDialog(
      title: const Text('Select Month for Payment'),
      content: SizedBox(
        height: 300,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Month'),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final month = months[index];
                  final currentMonth = DateFormat('MMM').format(DateTime.now());
                  final isSelected = month == currentMonth;

                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Select Year'),
                          content: SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: years.length,
                              itemBuilder: (context, yearIndex) {
                                final year = years[yearIndex];
                                return ListTile(
                                  title: Text(year.toString()),
                                  onTap: () {
                                    final monthName =
                                        '${month.padRight(3)} $year';
                                    setState(() {
                                      _selectedMonth = monthName;
                                      _fieldErrors.remove('month');
                                    });
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          month,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _validateForm() {
    setState(() {
      _fieldErrors.clear();

      // Validate amount
      final int? amount = int.tryParse(_amountController.text);
      final amountError = PaymentValidator.validatePaymentAmount(amount ?? 0);
      if (amountError != null) {
        _fieldErrors['amount'] = amountError;
      }

      // Validate month
      if (_selectedMonth.isEmpty) {
        _fieldErrors['month'] = 'Please select month';
      }

      // Validate payment method
      final methodError = PaymentValidator.validatePaymentMethod(
        _selectedPaymentMethod,
      );
      if (methodError != null) {
        _fieldErrors['paymentMethod'] = methodError;
      }

      // Validate payment date
      if (_paymentDate == null) {
        _fieldErrors['paymentDate'] = 'Please select payment date';
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
      _submitError = null;
    });

    try {
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get tenant to validate
      final tenantAsync = await ref.read(
        tenantProvider(widget.tenantId).future,
      );

      if (tenantAsync == null) {
        throw Exception('Tenant not found');
      }

      // Create payment entity
      final payment = PaymentEntity(
        id: '', // Firebase will generate
        tenantId: widget.tenantId,
        ownerId: userId,
        propertyId: widget.propertyId,
        amount: int.parse(_amountController.text),
        paymentDate: _paymentDate!,
        monthFor: _selectedMonth,
        paymentMethod: _selectedPaymentMethod,
        referenceId: _referenceIdController.text,
        status: 'paid',
        notes: _notesController.text,
        createdAt: DateTime.now(),
      );

      // Record payment via provider
      await ref.read(paymentNotifierProvider.notifier).recordPayment(payment);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _submitError = e.toString();
        _isLoading = false;
      });
      _showError(_submitError!);
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
        title: const Text('Record Payment'),
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
                  // Tenant Information Card
                  _buildTenantInfoCard(tenant),
                  const SizedBox(height: 24),

                  // Payment Details
                  _buildSectionTitle('Payment Details'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _amountController,
                    label: 'Amount Paid',
                    hint: 'Enter amount in rupees',
                    keyboardType: TextInputType.number,
                    error: _fieldErrors['amount'],
                  ),
                  const SizedBox(height: 12),

                  // Payment Method
                  _buildDropdownField(
                    label: 'Payment Method',
                    value: _selectedPaymentMethod,
                    items: const ['UPI', 'cash', 'bank_transfer', 'check'],
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Reference ID
                  _buildTextField(
                    controller: _referenceIdController,
                    label: 'Reference ID / Transaction ID',
                    hint: 'Enter transaction reference',
                    error: _fieldErrors['referenceId'],
                  ),
                  const SizedBox(height: 12),

                  // Payment Date
                  _buildDateField(
                    label: 'Payment Date',
                    value: _paymentDate,
                    onTap: _selectPaymentDate,
                    error: _fieldErrors['paymentDate'],
                  ),
                  const SizedBox(height: 24),

                  // Month for Payment
                  _buildSectionTitle('Month for Payment'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _selectMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _fieldErrors.containsKey('month')
                              ? Colors.red
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedMonth,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_fieldErrors.containsKey('month'))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _fieldErrors['month']!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Additional Notes
                  _buildSectionTitle('Additional Notes'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    hint: 'Add any notes about the payment',
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
                              'Record Payment',
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

  Widget _buildTenantInfoCard(dynamic tenant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.blueSurfaceGradient.colors.first.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.blueSurfaceGradient.colors.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tenant.fullName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room: ${tenant.roomNumber}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              Text(
                'Rent: ₹${tenant.rentAmount}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value != null
                      ? DateFormat('MMM dd, yyyy').format(value)
                      : 'Select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: value != null ? Colors.black : Colors.grey[600],
                  ),
                ),
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
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
