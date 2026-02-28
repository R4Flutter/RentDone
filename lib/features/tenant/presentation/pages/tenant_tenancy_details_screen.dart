import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_glass.dart';

class TenantTenancyDetailsScreen extends ConsumerStatefulWidget {
  const TenantTenancyDetailsScreen({super.key});

  @override
  ConsumerState<TenantTenancyDetailsScreen> createState() =>
      _TenantTenancyDetailsScreenState();
}

class _TenantTenancyDetailsScreenState
    extends ConsumerState<TenantTenancyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tenantNameController = TextEditingController();
  final _tenantEmailController = TextEditingController();
  final _tenantPhoneController = TextEditingController();

  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerUpiController = TextEditingController();

  final _propertyController = TextEditingController();
  final _roomController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  final _depositController = TextEditingController();
  final _rentDueDayController = TextEditingController();

  Timer? _syncRetryTimer;
  int _syncAttempts = 0;
  String? _activeTenantId;
  DateTime? _allocationDate;
  bool _isSaving = false;

  static const _maxSyncAttempts = 10;
  static const _syncRetryInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _stopAutoSync();
    _tenantNameController.dispose();
    _tenantEmailController.dispose();
    _tenantPhoneController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _ownerUpiController.dispose();
    _propertyController.dispose();
    _roomController.dispose();
    _monthlyRentController.dispose();
    _depositController.dispose();
    _rentDueDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load tenancy details: $e',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (summary) {
        if (summary.tenantId.isEmpty) {
          _startAutoSyncIfNeeded();
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text(
                    'Syncing tenant allocation details. Please wait...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        _stopAutoSync();

        final ownerAsync = ref.watch(
          tenantOwnerDetailsProvider(summary.tenantId),
        );
        final roomAsync = ref.watch(
          tenantRoomDetailsProvider(summary.tenantId),
        );
        final monthPaymentAsync = ref.watch(
          currentMonthPaymentProvider(summary.tenantId),
        );

        final ownerData = ownerAsync.maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );
        final roomData = roomAsync.maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );

        _hydrateFormIfNeeded(
          tenantId: summary.tenantId,
          summary: summary,
          ownerData: ownerData,
          roomData: roomData,
        );

        return Container(
          color: AppTheme.nearBlack,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
              children: [
                _HeaderCard(summaryName: summary.tenantName),
                const SizedBox(height: 12),
                _EditableSection(
                  title: 'Tenant Details',
                  children: [
                    _inputField(
                      controller: _tenantNameController,
                      label: 'Tenant Name',
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    _inputField(
                      controller: _tenantEmailController,
                      label: 'Tenant Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return 'Required';
                        if (!email.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    _inputField(
                      controller: _tenantPhoneController,
                      label: 'Tenant Phone',
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    _readOnlyInfo('Tenant ID', summary.tenantId),
                  ],
                ),
                const SizedBox(height: 12),
                _EditableSection(
                  title: 'Owner & Payment Details',
                  children: [
                    _inputField(
                      controller: _ownerNameController,
                      label: 'Owner Name',
                    ),
                    _inputField(
                      controller: _ownerPhoneController,
                      label: 'Owner Phone Number',
                      keyboardType: TextInputType.phone,
                    ),
                    _inputField(
                      controller: _ownerUpiController,
                      label: 'Owner UPI ID',
                      hintText: 'example@upi',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EditableSection(
                  title: 'Allocation, Room & Rent Details',
                  children: [
                    _inputField(
                      controller: _propertyController,
                      label: 'Property Name',
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    _inputField(
                      controller: _roomController,
                      label: 'Room Number',
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    _inputField(
                      controller: _monthlyRentController,
                      label: 'Monthly Rent',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final amount = int.tryParse((value ?? '').trim()) ?? 0;
                        if (amount <= 0) return 'Rent should be greater than 0';
                        return null;
                      },
                    ),
                    _inputField(
                      controller: _depositController,
                      label: 'Deposit Amount',
                      keyboardType: TextInputType.number,
                    ),
                    _inputField(
                      controller: _rentDueDayController,
                      label: 'Rent Due Day (1-31)',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final day = int.tryParse((value ?? '').trim()) ?? 0;
                        if (day < 1 || day > 31) {
                          return 'Enter a day between 1 and 31';
                        }
                        return null;
                      },
                    ),
                    _datePickerField(context),
                  ],
                ),
                const SizedBox(height: 12),
                monthPaymentAsync.when(
                  loading: () =>
                      const _SectionLoading(title: 'Current Month Payment'),
                  error: (_, _) => const _InfoSection(
                    title: 'Current Month Payment',
                    children: [
                      _ReadOnlyInfoTile(
                        label: 'Status',
                        value: 'Not available right now',
                      ),
                    ],
                  ),
                  data: (payment) => _InfoSection(
                    title: 'Current Month Payment',
                    children: [
                      _ReadOnlyInfoTile(
                        label: 'Status',
                        value: payment == null
                            ? 'Pending'
                            : payment.status.toUpperCase(),
                      ),
                      _ReadOnlyInfoTile(
                        label: 'Amount',
                        value: _formatCurrency(
                          payment?.amount ??
                              (int.tryParse(
                                    _monthlyRentController.text.trim(),
                                  ) ??
                                  0),
                        ),
                      ),
                      _ReadOnlyInfoTile(
                        label: 'Payment Method',
                        value: payment?.paymentMethod.toUpperCase() ?? 'UPI',
                      ),
                      _ReadOnlyInfoTile(
                        label: 'Paid Date',
                        value: _formatDate(payment?.paidDate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _saveAllDetails(tenantId: summary.tenantId),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save All Details'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hydrateFormIfNeeded({
    required String tenantId,
    required dynamic summary,
    required TenantOwnerDetails? ownerData,
    required TenantRoomDetails? roomData,
  }) {
    if (_activeTenantId != tenantId) {
      _activeTenantId = tenantId;

      _tenantNameController.text = summary.tenantName;
      _tenantEmailController.text = summary.tenantEmail;
      _tenantPhoneController.text = summary.tenantPhone;

      _ownerNameController.text = ownerData?.ownerName ?? '';
      _ownerPhoneController.text =
          ownerData?.ownerPhoneNumber.isNotEmpty == true
          ? ownerData!.ownerPhoneNumber
          : summary.ownerPhoneNumber;
      _ownerUpiController.text = ownerData?.ownerUpiId ?? '';

      _propertyController.text = roomData?.propertyName.isNotEmpty == true
          ? roomData!.propertyName
          : summary.propertyName;
      _roomController.text = roomData?.roomNumber.isNotEmpty == true
          ? roomData!.roomNumber
          : summary.roomNumber;
      _monthlyRentController.text =
          (roomData?.monthlyRent ?? summary.monthlyRent).toString();
      _depositController.text =
          ((roomData?.depositAmount ?? summary.depositAmount) ?? 0).toString();
      _rentDueDayController.text = (roomData?.rentDueDay ?? summary.rentDueDay)
          .toString();
      _allocationDate = roomData?.allocationDate ?? summary.allocationDate;
      return;
    }

    if (_ownerNameController.text.trim().isEmpty &&
        (ownerData?.ownerName ?? '').trim().isNotEmpty) {
      _ownerNameController.text = ownerData!.ownerName;
    }
    if (_ownerPhoneController.text.trim().isEmpty &&
        (ownerData?.ownerPhoneNumber ?? '').trim().isNotEmpty) {
      _ownerPhoneController.text = ownerData!.ownerPhoneNumber;
    }
    if (_ownerUpiController.text.trim().isEmpty &&
        (ownerData?.ownerUpiId ?? '').trim().isNotEmpty) {
      _ownerUpiController.text = ownerData!.ownerUpiId;
    }
  }

  Future<void> _saveAllDetails({required String tenantId}) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final monthlyRent = int.tryParse(_monthlyRentController.text.trim()) ?? 0;
    final depositRaw = _depositController.text.trim();
    final depositAmount = int.tryParse(depositRaw);
    final rentDueDay = int.tryParse(_rentDueDayController.text.trim()) ?? 1;

    setState(() => _isSaving = true);

    try {
      await saveTenantBasicDetails(
        ref,
        tenantId: tenantId,
        tenantName: _tenantNameController.text.trim(),
        tenantEmail: _tenantEmailController.text.trim(),
        tenantPhone: _tenantPhoneController.text.trim(),
      );

      await saveTenantOwnerDetails(
        ref,
        tenantId: tenantId,
        details: TenantOwnerDetails(
          ownerPhoneNumber: _ownerPhoneController.text.trim(),
          ownerUpiId: _ownerUpiController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
        ),
      );

      await saveTenantRoomDetails(
        ref,
        tenantId: tenantId,
        details: TenantRoomDetails(
          propertyName: _propertyController.text.trim(),
          roomNumber: _roomController.text.trim(),
          monthlyRent: monthlyRent,
          depositAmount: depositAmount,
          allocationDate: _allocationDate ?? DateTime.now(),
          rentDueDay: rentDueDay,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All tenant details saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(labelText: label, hintText: hintText)
            .copyWith(
              labelStyle: tenantGlassInputDecoration(
                context,
                label: label,
                hint: hintText,
              ).labelStyle,
              hintStyle: tenantGlassInputDecoration(
                context,
                label: label,
                hint: hintText,
              ).hintStyle,
              filled: tenantGlassInputDecoration(
                context,
                label: label,
                hint: hintText,
              ).filled,
              fillColor: tenantGlassInputDecoration(
                context,
                label: label,
                hint: hintText,
              ).fillColor,
              border: tenantGlassInputDecoration(
                context,
                label: label,
                hint: hintText,
              ).border,
              enabledBorder: tenantGlassInputDecoration(
                context,
                label: label,
                hint: hintText,
              ).enabledBorder,
              focusedBorder: tenantGlassInputDecoration(
                context,
                label: label,
                hint: hintText,
              ).focusedBorder,
            ),
      ),
    );
  }

  Widget _datePickerField(BuildContext context) {
    final dateText = _allocationDate == null
        ? 'Select allocation date'
        : DateFormat('dd MMM yyyy').format(_allocationDate!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _allocationDate ?? DateTime.now(),
            firstDate: DateTime(2010),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (picked != null && mounted) {
            setState(() {
              _allocationDate = picked;
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_outlined,
                color: Colors.white.withValues(alpha: 0.82),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dateText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyInfo(String label, String value) {
    return _ReadOnlyInfoTile(label: label, value: value);
  }

  void _startAutoSyncIfNeeded() {
    if (_syncRetryTimer != null || !mounted) {
      return;
    }

    _syncAttempts = 0;
    _syncRetryTimer = Timer.periodic(_syncRetryInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      final hasTenantId = ref
          .read(tenantDashboardProvider)
          .maybeWhen(
            data: (summary) => summary.tenantId.isNotEmpty,
            orElse: () => false,
          );

      if (hasTenantId) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      _syncAttempts += 1;
      ref.invalidate(tenantDashboardProvider);

      if (_syncAttempts >= _maxSyncAttempts) {
        timer.cancel();
        _syncRetryTimer = null;
      }
    });
  }

  void _stopAutoSync() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  String _formatCurrency(int amount) {
    return '₹${NumberFormat('#,##,##0', 'en_IN').format(amount)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }
}

class _HeaderCard extends StatelessWidget {
  final String summaryName;

  const _HeaderCard({required this.summaryName});

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      accent: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/rentdone_logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RentDone Tenancy Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  summaryName,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditableSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return TenantGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyInfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = value.trim().isEmpty ? 'Not available' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              normalized,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  final String title;

  const _SectionLoading({required this.title});

  @override
  Widget build(BuildContext context) {
    return _InfoSection(
      title: title,
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      ],
    );
  }
}
