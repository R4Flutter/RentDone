import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_stat_card.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  ConsumerState<TenantDashboardScreen> createState() =>
      _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen> {
  final _propertyController = TextEditingController();
  final _roomController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _amountPaidController = TextEditingController();

  Timer? _syncRetryTimer;
  int _syncAttempts = 0;
  DateTime? _allocationDate;
  DateTime? _paymentDate;
  String _paymentMethod = 'Cash';

  static const _maxSyncAttempts = 10;
  static const _syncRetryInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _stopAutoSync();
    _propertyController.dispose();
    _roomController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _ownerPhoneController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(tenantDashboardProvider);
    final theme = Theme.of(context);

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
                    'Setting up your tenant account. Dashboard will load automatically.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        _stopAutoSync();

        final monthlyPaymentAsync = summary.tenantId.isEmpty
            ? const AsyncValue.data(null)
            : ref.watch(currentMonthPaymentProvider(summary.tenantId));
        final roomDetailsAsync = ref.watch(
          tenantRoomDetailsProvider(summary.tenantId),
        );
        final ownerDetailsAsync = ref.watch(
          tenantOwnerDetailsProvider(summary.tenantId),
        );
        final recentDocsAsync = ref.watch(
          recentTenantDocumentsProvider(summary.tenantId),
        );
        final remindersAsync = ref.watch(
          recentTenantRemindersProvider(summary.tenantId),
        );

        return RefreshIndicator(
          onRefresh: () => _refreshDashboard(summary.tenantId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hello, ${summary.tenantName}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Financial Summary', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 700 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      TenantStatCard(
                        title: 'Due Amount',
                        value: summary.dueAmount > 0
                            ? '\u20B9${_formatInr(summary.dueAmount)}'
                            : 'No Dues',
                        subtitle: summary.dueAmount > 0
                            ? 'Pending rent amount'
                            : 'Everything is clear',
                        icon: Icons.warning_amber_rounded,
                        color: summary.dueAmount > 0
                            ? AppTheme.errorRed
                            : AppTheme.successGreen,
                      ),
                      monthlyPaymentAsync.when(
                        data: (payment) => TenantStatCard(
                          title: '${summary.currentMonthName} Payment',
                          value: '\u20B9${_formatInr(payment?.amount ?? 0)}',
                          subtitle: payment?.paidDate != null
                              ? 'Paid on ${_formatDate(payment!.paidDate!)}'
                              : 'No payment recorded',
                          icon: Icons.currency_rupee_rounded,
                          color: AppTheme.primaryBlue,
                        ),
                        loading: () => const Card(
                          elevation: 2,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => const TenantStatCard(
                          title: 'Monthly Payment',
                          value: '\u20B90',
                          subtitle: 'Unable to load',
                          icon: Icons.currency_rupee_rounded,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      TenantStatCard(
                        title: 'Lifetime Paid',
                        value: '\u20B9${_formatInr(summary.lifetimePaid)}',
                        subtitle: 'All-time payments',
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppTheme.successGreen,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _roomAndPropertyCard(
                context,
                summary,
                roomDetailsAsync,
                monthlyPaymentAsync,
              ),
              const SizedBox(height: 12),
              _ownerContactCard(context, summary, ownerDetailsAsync),
              const SizedBox(height: 12),
              _paymentActionCard(context, summary, monthlyPaymentAsync),
              const SizedBox(height: 12),
              _recentRemindersCard(remindersAsync),
              const SizedBox(height: 18),
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _quickAction(
                    context,
                    icon: Icons.description_outlined,
                    title: 'Documents',
                    onTap: () => context.go('/tenant/documents'),
                  ),
                  _quickAction(
                    context,
                    icon: Icons.report_problem_outlined,
                    title: 'Complaints',
                    onTap: () => context.go('/tenant/complaints'),
                  ),
                  _quickAction(
                    context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Payments',
                    onTap: () => context.go('/tenant/transactions'),
                  ),
                  _quickAction(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    onTap: () => context.go('/tenant/profile'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Documents',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/tenant/documents'),
                    child: const Text('View all'),
                  ),
                ],
              ),
              recentDocsAsync.when(
                data: (docs) {
                  if (docs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No recent documents yet'),
                      ),
                    );
                  }

                  return Column(
                    children: docs
                        .map(
                          (document) => _recentDocumentTile(context, document),
                        )
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline_rounded),
                    title: const Text('Failed to load recent documents'),
                    trailing: TextButton(
                      onPressed: () => ref.invalidate(
                        recentTenantDocumentsProvider(summary.tenantId),
                      ),
                      child: const Text('Retry'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshDashboard(String tenantId) async {
    ref.invalidate(tenantDashboardProvider);
    ref.invalidate(currentMonthPaymentProvider(tenantId));
    ref.invalidate(tenantRoomDetailsProvider(tenantId));
    ref.invalidate(tenantOwnerDetailsProvider(tenantId));
    ref.invalidate(recentTenantDocumentsProvider(tenantId));
    ref.invalidate(recentTenantRemindersProvider(tenantId));

    await ref.read(tenantDashboardProvider.future);
    await ref.read(tenantRoomDetailsProvider(tenantId).future);
    await ref.read(tenantOwnerDetailsProvider(tenantId).future);
    await ref.read(recentTenantDocumentsProvider(tenantId).future);
    await ref.read(recentTenantRemindersProvider(tenantId).future);
  }

  Widget _recentRemindersCard(AsyncValue<List<TenantReminder>> remindersAsync) {
    return _buildGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Reminders', style: _cardTitleStyle),
          const SizedBox(height: 8),
          remindersAsync.when(
            data: (reminders) {
              if (reminders.isEmpty) {
                return Text('No reminders yet.', style: _cardBodyStyle);
              }

              return Column(
                children: reminders
                    .map(
                      (reminder) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                          color: Colors.white,
                        ),
                        title: Text(
                          reminder.title.isEmpty
                              ? 'Rent Payment Reminder'
                              : reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _cardBodyStyle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          reminder.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _cardBodyStyle,
                        ),
                        trailing: Text(
                          reminder.createdAt != null
                              ? _formatDate(reminder.createdAt!)
                              : '-',
                          style: _cardBodyStyle.copyWith(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            error: (_, _) =>
                Text('Unable to load reminders.', style: _cardBodyStyle),
          ),
        ],
      ),
    );
  }

  Widget _roomAndPropertyCard(
    BuildContext context,
    dynamic summary,
    AsyncValue<TenantRoomDetails?> roomDetailsAsync,
    AsyncValue<dynamic> monthlyPaymentAsync,
  ) {
    final roomDetails = _asyncData<TenantRoomDetails?>(roomDetailsAsync);
    final propertyName = roomDetails?.propertyName.isNotEmpty == true
        ? roomDetails!.propertyName
        : summary.propertyName;
    final roomNo = roomDetails?.roomNumber.isNotEmpty == true
        ? roomDetails!.roomNumber
        : summary.roomNumber;
    final monthlyRent =
        roomDetails?.monthlyRent != null && roomDetails!.monthlyRent > 0
        ? roomDetails.monthlyRent
        : summary.monthlyRent;
    final dueDay = roomDetails?.rentDueDay ?? summary.rentDueDay;
    final daysLeft = _daysUntilDue(dueDay);
    final payment = _asyncData<dynamic>(monthlyPaymentAsync);
    final paidThisMonth = payment?.isPaid == true;

    return _buildGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Current Property', style: _cardTitleStyle)),
              _cardActionButton(
                label: propertyName.isEmpty ? 'Add' : 'Edit',
                onTap: () => _openRoomDetailsSheet(summary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Property: ${propertyName.isEmpty ? '-' : propertyName}',
            style: _cardBodyStyle,
          ),
          Text('Room: ${roomNo.isEmpty ? '-' : roomNo}', style: _cardBodyStyle),
          Text(
            'Monthly Rent: ${monthlyRent > 0 ? '\u20B9${_formatInr(monthlyRent)}' : '-'}',
            style: _cardBodyStyle,
          ),
          Text('Due Date: Day $dueDay of each month', style: _cardBodyStyle),
          Text(
            'Next Payment Status: ${paidThisMonth ? 'Paid' : 'Pending'}',
            style: _cardBodyStyle,
          ),
          Text(
            'Total Paid: \u20B9${_formatInr(summary.lifetimePaid)}',
            style: _cardBodyStyle,
          ),
          if (!paidThisMonth && daysLeft <= 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                daysLeft < 0
                    ? 'Payment overdue. Please pay owner now.'
                    : 'Reminder: rent due in $daysLeft day(s).',
                style: _cardBodyStyle.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ownerContactCard(
    BuildContext context,
    dynamic summary,
    AsyncValue<TenantOwnerDetails?> ownerDetailsAsync,
  ) {
    final ownerDetails = _asyncData<TenantOwnerDetails?>(ownerDetailsAsync);
    final phone = ownerDetails?.ownerPhoneNumber.isNotEmpty == true
        ? ownerDetails!.ownerPhoneNumber
        : summary.ownerPhoneNumber;

    return _buildGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Owner Contact', style: _cardTitleStyle)),
              _cardActionButton(
                label: phone.isEmpty ? 'Add' : 'Edit',
                onTap: () => _openOwnerPhoneSheet(summary),
              ),
            ],
          ),
          Text('Phone: ${phone.isEmpty ? '-' : phone}', style: _cardBodyStyle),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: phone.isEmpty ? null : () => _callPhone(phone),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
              disabledForegroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call Owner'),
          ),
        ],
      ),
    );
  }

  Widget _paymentActionCard(
    BuildContext context,
    dynamic summary,
    AsyncValue<dynamic> monthlyPaymentAsync,
  ) {
    final payment = _asyncData<dynamic>(monthlyPaymentAsync);
    return _buildGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Action', style: _cardTitleStyle),
          const SizedBox(height: 6),
          Text(
            'Current Month: ${payment?.isPaid == true ? 'Paid (${payment.paymentMethod})' : 'Not marked yet'}',
            style: _cardBodyStyle,
          ),
          if (summary.ownerPhoneNumber.isNotEmpty)
            Text(
              'Payment Reference (Owner): ${summary.ownerPhoneNumber}',
              style: _cardBodyStyle,
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _openMarkPaidSheet(summary),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryBlue,
            ),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _cardActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }

  TextStyle get _cardTitleStyle => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  TextStyle get _cardBodyStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    height: 1.35,
  );

  Future<void> _openRoomDetailsSheet(dynamic summary) async {
    TenantRoomDetails? existing;
    try {
      existing = await ref.read(
        tenantRoomDetailsProvider(summary.tenantId).future,
      );
    } catch (_) {
      existing = null;
    }
    _propertyController.text = existing?.propertyName ?? summary.propertyName;
    _roomController.text = existing?.roomNumber ?? summary.roomNumber;
    _rentController.text = (existing?.monthlyRent ?? summary.monthlyRent)
        .toString();
    _depositController.text =
        (existing?.depositAmount ?? summary.depositAmount ?? '').toString();
    _allocationDate = existing?.allocationDate ?? summary.allocationDate;
    final dueDay = existing?.rentDueDay ?? summary.rentDueDay;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final dueController = TextEditingController(text: dueDay.toString());
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _propertyController,
                decoration: const InputDecoration(labelText: 'Property Name'),
              ),
              TextField(
                controller: _roomController,
                decoration: const InputDecoration(labelText: 'Room Number'),
              ),
              TextField(
                controller: _rentController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Monthly Rent'),
              ),
              TextField(
                controller: _depositController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Deposit Amount (optional)',
                ),
              ),
              TextField(
                controller: dueController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Rent Due Day (1-31)',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: _allocationDate ?? DateTime.now(),
                    );
                    if (selected != null) {
                      setState(() => _allocationDate = selected);
                    }
                  },
                  child: Text(
                    _allocationDate == null
                        ? 'Select Allocation Date'
                        : 'Allocation Date: ${_formatDate(_allocationDate!)}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  final rent = int.tryParse(_rentController.text.trim()) ?? 0;
                  final due = int.tryParse(dueController.text.trim()) ?? 0;
                  final allocation = _allocationDate;
                  if (_propertyController.text.trim().isEmpty ||
                      _roomController.text.trim().isEmpty ||
                      rent <= 0 ||
                      due < 1 ||
                      due > 31 ||
                      allocation == null ||
                      allocation.isAfter(DateTime.now())) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter valid room details.'),
                      ),
                    );
                    return;
                  }

                  try {
                    await saveTenantRoomDetails(
                      ref,
                      tenantId: summary.tenantId,
                      details: TenantRoomDetails(
                        propertyName: _propertyController.text.trim(),
                        roomNumber: _roomController.text.trim(),
                        monthlyRent: rent,
                        depositAmount: int.tryParse(
                          _depositController.text.trim(),
                        ),
                        allocationDate: allocation,
                        rentDueDay: due,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text(_friendlyActionError(e))),
                    );
                    return;
                  }

                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                },
                child: const Text('Save Room Details'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openOwnerPhoneSheet(dynamic summary) async {
    TenantOwnerDetails? existing;
    try {
      existing = await ref.read(
        tenantOwnerDetailsProvider(summary.tenantId).future,
      );
    } catch (_) {
      existing = null;
    }
    _ownerPhoneController.text =
        existing?.ownerPhoneNumber ?? summary.ownerPhoneNumber;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _ownerPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Owner Phone Number',
                  counterText: '',
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final phone = _ownerPhoneController.text.trim();
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter valid 10-digit Indian mobile number.',
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    await saveTenantOwnerDetails(
                      ref,
                      tenantId: summary.tenantId,
                      details: TenantOwnerDetails(ownerPhoneNumber: phone),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text(_friendlyActionError(e))),
                    );
                    return;
                  }

                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                },
                child: const Text('Save Owner Number'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMarkPaidSheet(dynamic summary) async {
    _amountPaidController.text = summary.monthlyRent > 0
        ? summary.monthlyRent.toString()
        : '';
    _paymentDate = DateTime.now();
    _paymentMethod = 'Cash';

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _amountPaidController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Amount Paid'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'Bank Transfer',
                        child: Text('Bank Transfer'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => _paymentMethod = value);
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          initialDate: _paymentDate ?? DateTime.now(),
                        );
                        if (selected != null) {
                          setModalState(() => _paymentDate = selected);
                        }
                      },
                      child: Text(
                        _paymentDate == null
                            ? 'Select Payment Date'
                            : 'Payment Date: ${_formatDate(_paymentDate!)}',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final amount =
                          int.tryParse(_amountPaidController.text.trim()) ?? 0;
                      final date = _paymentDate;
                      if (amount <= 0 || date == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter valid payment details.'),
                          ),
                        );
                        return;
                      }
                      if (summary.monthlyRent > 0 &&
                          amount != summary.monthlyRent) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Amount must be exactly \u20B9${_formatInr(summary.monthlyRent)} for this month.',
                            ),
                          ),
                        );
                        return;
                      }

                      try {
                        await markTenantPaymentAsPaid(
                          ref,
                          tenantId: summary.tenantId,
                          amountPaid: amount,
                          paymentDate: date,
                          paymentMethod: _paymentMethod,
                          monthlyRent: summary.monthlyRent,
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(_friendlyActionError(e))),
                        );
                        return;
                      }

                      if (!mounted) return;
                      Navigator.of(this.context).pop();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Save Payment'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _callPhone(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$normalized');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  int _daysUntilDue(int dueDay) {
    final now = DateTime.now();
    final safeDue = dueDay.clamp(1, 31);
    final lastDayCurrent = DateTime(now.year, now.month + 1, 0).day;
    final currentDueDate = DateTime(
      now.year,
      now.month,
      safeDue > lastDayCurrent ? lastDayCurrent : safeDue,
    );
    if (!now.isAfter(currentDueDate)) {
      return currentDueDate
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
    }
    final nextMonthLastDay = DateTime(now.year, now.month + 2, 0).day;
    final nextDueDate = DateTime(
      now.year,
      now.month + 1,
      safeDue > nextMonthLastDay ? nextMonthLastDay : safeDue,
    );
    return nextDueDate
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  T? _asyncData<T>(AsyncValue<T> value) {
    return value.maybeWhen(data: (data) => data, orElse: () => null);
  }

  String _friendlyActionError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission-denied')) {
      return 'Access rules are not deployed for this action yet. Please deploy latest Firestore rules.';
    }
    if (text.contains('monthly rent must be greater than zero')) {
      return 'Monthly rent must be greater than zero.';
    }
    if (text.contains('rent due day must be between 1 and 31')) {
      return 'Rent due day must be between 1 and 31.';
    }
    if (text.contains('amount must match monthly rent')) {
      return 'Amount should match monthly rent for mark as paid.';
    }
    return 'Action failed. Please try again.';
  }

  Widget _recentDocumentTile(BuildContext context, TenantDocument document) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _openDocument(document.fileUrl),
        leading: Icon(_documentTypeIcon(document.fileType)),
        title: Text(
          document.description.isEmpty
              ? 'Uploaded document'
              : document.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          document.uploadedAt != null
              ? 'Uploaded ${_formatDate(document.uploadedAt!)}'
              : 'Uploaded recently',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      ),
    );
  }

  IconData _documentTypeIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _openDocument(String fileUrl) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _formatInr(int value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    if (digits.length <= 3) return '$sign$digits';

    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) {
      parts.insert(0, rest);
    }
    return '$sign${parts.join(',')},$last3';
  }

  String _formatDate(DateTime date) {
    const months = [
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
