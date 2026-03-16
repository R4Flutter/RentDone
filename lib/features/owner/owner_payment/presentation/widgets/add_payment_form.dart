import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class AddPaymentPayload {
  const AddPaymentPayload({
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
    this.notes,
  });

  final int amount;
  final DateTime date;
  final String method;
  final String status;
  final String? notes;
}

class AddPaymentForm extends StatefulWidget {
  const AddPaymentForm({super.key, required this.onSubmit});

  final Future<void> Function(AddPaymentPayload payload) onSubmit;

  @override
  State<AddPaymentForm> createState() => _AddPaymentFormState();
}

class _AddPaymentFormState extends State<AddPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedMethod = 'UPI';
  String _selectedStatus = 'paid';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Payment',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: OwnerDashboardColors.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'Rs ',
              ),
              validator: (value) {
                final amount = int.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _inputChip(
                    context,
                    label: _dateLabel(_selectedDate),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedMethod,
              items: const ['UPI', 'Cash', 'Bank Transfer']
                  .map(
                    (method) =>
                        DropdownMenuItem(value: method, child: Text(method)),
                  )
                  .toList(),
              decoration: const InputDecoration(labelText: 'Payment Method'),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMethod = value);
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              items: const [
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'partial', child: Text('Partial')),
                DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              ],
              decoration: const InputDecoration(labelText: 'Payment Status'),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: OwnerDashboardColors.brandPrimary(context),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OwnerDashboardColors.border(context)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountCtrl.text.trim());
    final notes = _notesCtrl.text.trim();

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(
        AddPaymentPayload(
          amount: amount,
          date: _selectedDate,
          method: _selectedMethod,
          status: _selectedStatus,
          notes: notes.isEmpty ? null : notes,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _dateLabel(DateTime date) {
    const months = <String>[
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
