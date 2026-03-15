import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/providers/payments_provider.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/providers/property_tenant_provider.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  final String? initialTenantId;
  final String? initialPropertyId;
  final String? initialTenantName;

  const PaymentsScreen({
    super.key,
    this.initialStatus,
    this.initialTenantId,
    this.initialPropertyId,
    this.initialTenantName,
  });

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String selectedMonth = 'All Months';
  String selectedPropertyId = 'all';
  String selectedTenantId = 'all';
  late String selectedStatus;

  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedStatus = _normalizeStatus(widget.initialStatus);
    selectedPropertyId = (widget.initialPropertyId?.trim().isNotEmpty ?? false)
        ? widget.initialPropertyId!.trim()
        : 'all';
    selectedTenantId = (widget.initialTenantId?.trim().isNotEmpty ?? false)
        ? widget.initialTenantId!.trim()
        : 'all';
  }

  @override
  void didUpdateWidget(covariant PaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus ||
        oldWidget.initialTenantId != widget.initialTenantId ||
        oldWidget.initialPropertyId != widget.initialPropertyId) {
      setState(() {
        selectedStatus = _normalizeStatus(widget.initialStatus);
        selectedPropertyId =
            (widget.initialPropertyId?.trim().isNotEmpty ?? false)
            ? widget.initialPropertyId!.trim()
            : 'all';
        selectedTenantId = (widget.initialTenantId?.trim().isNotEmpty ?? false)
            ? widget.initialTenantId!.trim()
            : 'all';
      });
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final paymentsAsync = ref.watch(paymentsProvider);
    final propertiesAsync = ref.watch(allPropertiesProvider);
    final tenantsAsync = ref.watch(allTenantsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    OwnerDashboardColors.managePropertiesBackgroundGradient(
                      context,
                    ),
              ),
            ),
          ),
          _liquidBlob(top: -88, left: -62, size: 300, isDark: isDark),
          _liquidBlob(bottom: -92, right: -70, size: 260, isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: _header(context),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(paymentsProvider);
                      ref.invalidate(allPropertiesProvider);
                      ref.invalidate(allTenantsProvider);
                    },
                    child: paymentsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => _errorState(context, err.toString()),
                      data: (payments) {
                        final properties =
                            propertiesAsync.value ?? const <Property>[];
                        final tenants = tenantsAsync.value ?? const <Tenant>[];

                        final propertyNameById = {
                          for (final property in properties)
                            property.id: property.name,
                        };
                        final tenantNameById = {
                          for (final tenant in tenants)
                            tenant.id: tenant.fullName,
                        };
                        final tenantById = {
                          for (final tenant in tenants) tenant.id: tenant,
                        };

                        final monthOptions = _buildMonthOptions(payments);
                        final propertyOptions = _buildPropertyOptions(
                          properties,
                        );
                        final tenantOptions = _buildTenantOptions(tenants);

                        final effectiveMonth =
                            monthOptions.contains(selectedMonth)
                            ? selectedMonth
                            : 'All Months';
                        final effectivePropertyId =
                            propertyOptions.any(
                              (element) => element.value == selectedPropertyId,
                            )
                            ? selectedPropertyId
                            : 'all';
                        final effectiveTenantId =
                            tenantOptions.any(
                              (element) => element.value == selectedTenantId,
                            )
                            ? selectedTenantId
                            : 'all';

                        final filteredPayments = payments.where((payment) {
                          final monthKey = payment.periodKey.isNotEmpty
                              ? payment.periodKey
                              : _monthKey(payment.dueDate);

                          if (effectiveMonth != 'All Months' &&
                              monthKey != effectiveMonth) {
                            return false;
                          }
                          if (effectivePropertyId != 'all' &&
                              payment.propertyId != effectivePropertyId) {
                            return false;
                          }
                          if (effectiveTenantId != 'all' &&
                              payment.tenantId != effectiveTenantId) {
                            return false;
                          }
                          if (selectedStatus != 'All' &&
                              payment.status != selectedStatus.toLowerCase()) {
                            return false;
                          }
                          if (searchCtrl.text.trim().isNotEmpty) {
                            final query = searchCtrl.text.trim().toLowerCase();
                            final name =
                                (tenantNameById[payment.tenantId] ?? '')
                                    .toLowerCase();
                            if (!name.contains(query)) return false;
                          }
                          return true;
                        }).toList();

                        final expected = filteredPayments.fold<int>(
                          0,
                          (sum, payment) => sum + payment.amount,
                        );
                        final collected = filteredPayments
                            .where((payment) => payment.status == 'paid')
                            .fold<int>(
                              0,
                              (sum, payment) => sum + payment.amount,
                            );
                        final pending = filteredPayments
                            .where((payment) => payment.status == 'pending')
                            .fold<int>(
                              0,
                              (sum, payment) => sum + payment.amount,
                            );
                        final overdue = filteredPayments
                            .where((payment) => payment.status == 'overdue')
                            .fold<int>(
                              0,
                              (sum, payment) => sum + payment.amount,
                            );
                        final collectionRate = expected == 0
                            ? 0
                            : ((collected / expected) * 100).round();

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth > 1000;

                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: isDesktop
                                        ? 1400
                                        : double.infinity,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _filtersCard(
                                        context,
                                        monthOptions,
                                        propertyOptions,
                                        effectiveMonth,
                                        effectivePropertyId,
                                        tenantOptions,
                                        effectiveTenantId,
                                      ),
                                      const SizedBox(height: 18),
                                      _kpiStrip(
                                        context,
                                        expected,
                                        collected,
                                        pending,
                                        overdue,
                                        collectionRate,
                                      ),
                                      const SizedBox(height: 20),
                                      isDesktop
                                          ? _desktopTable(
                                              context,
                                              filteredPayments,
                                              propertyNameById,
                                              tenantNameById,
                                              tenantById,
                                            )
                                          : _mobileList(
                                              context,
                                              filteredPayments,
                                              propertyNameById,
                                              tenantNameById,
                                              tenantById,
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final title = (widget.initialTenantName?.trim().isNotEmpty ?? false)
        ? 'Payments - ${widget.initialTenantName!.trim()}'
        : 'Payments';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                    context,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Live Firebase collections for dues, paid, and overdue tracking',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                    context,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _headerAction(
          context,
          icon: Icons.receipt_long_rounded,
          label: 'Transactions',
          onTap: () => context.go('/owner/transactions'),
        ),
        const SizedBox(width: 8),
        _headerAction(
          context,
          icon: Icons.file_download_outlined,
          label: 'Export',
          onTap: _exportCurrentView,
        ),
      ],
    );
  }

  Widget _headerAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 38,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: OwnerDashboardColors.managePropertiesActionColor(
            context,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }

  Widget _filtersCard(
    BuildContext context,
    List<String> monthOptions,
    List<DropdownMenuItem<String>> propertyOptions,
    String effectiveMonth,
    String effectivePropertyId,
    List<DropdownMenuItem<String>> tenantOptions,
    String effectiveTenantId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withAlpha(20), Colors.white.withAlpha(10)]
                  : [Colors.white.withAlpha(188), Colors.white.withAlpha(140)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withAlpha(48),
              width: 1.2,
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dropdownField(
                context,
                label: 'Month',
                child: DropdownButtonFormField<String>(
                  value: effectiveMonth,
                  onChanged: (value) => setState(() => selectedMonth = value!),
                  items: monthOptions
                      .map(
                        (month) =>
                            DropdownMenuItem(value: month, child: Text(month)),
                      )
                      .toList(),
                ),
              ),
              _dropdownField(
                context,
                label: 'Property',
                child: DropdownButtonFormField<String>(
                  value: effectivePropertyId,
                  onChanged: (value) =>
                      setState(() => selectedPropertyId = value!),
                  items: propertyOptions,
                ),
              ),
              _dropdownField(
                context,
                label: 'Tenant',
                child: DropdownButtonFormField<String>(
                  value: effectiveTenantId,
                  onChanged: (value) =>
                      setState(() => selectedTenantId = value!),
                  items: tenantOptions,
                ),
              ),
              _dropdownField(
                context,
                label: 'Status',
                child: DropdownButtonFormField<String>(
                  value: selectedStatus,
                  onChanged: (value) => setState(() => selectedStatus = value!),
                  items: const ['All', 'Paid', 'Pending', 'Overdue']
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search tenant...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppTheme.pureWhite.withAlpha(96),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.liquidPrimaryStart.withAlpha(42),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.liquidPrimaryStart.withAlpha(42),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.liquidPrimaryEnd.withAlpha(160),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownField(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                context,
              ),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _kpiStrip(
    BuildContext context,
    int expected,
    int collected,
    int pending,
    int overdue,
    int collectionRate,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard(
          context,
          'Expected',
          'Rs $expected',
          Icons.assessment_outlined,
        ),
        _kpiCard(context, 'Collected', 'Rs $collected', Icons.check_circle),
        _kpiCard(context, 'Pending', 'Rs $pending', Icons.timelapse_rounded),
        _kpiCard(context, 'Overdue', 'Rs $overdue', Icons.error_outline),
        _kpiCard(context, 'Collection', '$collectionRate%', Icons.insights),
      ],
    );
  }

  Widget _kpiCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withAlpha(130),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.liquidPrimaryStart.withAlpha(42)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: OwnerDashboardColors.managePropertiesAccentGradient(
                context,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                      context,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                      context,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopTable(
    BuildContext context,
    List<Payment> payments,
    Map<String, String> propertyNameById,
    Map<String, String> tenantNameById,
    Map<String, Tenant> tenantById,
  ) {
    if (payments.isEmpty) {
      return _emptyState(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withAlpha(130),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withAlpha(42),
            ),
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Tenant')),
              DataColumn(label: Text('Property')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Action')),
            ],
            rows: payments.map((payment) {
              final tenantName = tenantNameById[payment.tenantId] ?? 'Unknown';
              final propertyName =
                  propertyNameById[payment.propertyId] ?? 'Unknown';
              return DataRow(
                cells: [
                  DataCell(Text(tenantName)),
                  DataCell(Text(propertyName)),
                  DataCell(Text('Rs ${payment.amount}')),
                  DataCell(Text(_formatDate(payment.dueDate))),
                  DataCell(_statusChip(context, payment.status)),
                  DataCell(
                    _actionCell(context, payment, tenantById[payment.tenantId]),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _actionCell(BuildContext context, Payment payment, Tenant? tenant) {
    if (payment.status == 'paid') {
      return const Text('Paid');
    }

    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: OwnerDashboardColors.managePropertiesActionColor(
          context,
        ),
        minimumSize: const Size(90, 32),
      ),
      onPressed: () => _showPaymentActions(payment, tenant),
      child: const Text('Collect'),
    );
  }

  Widget _mobileList(
    BuildContext context,
    List<Payment> payments,
    Map<String, String> propertyNameById,
    Map<String, String> tenantNameById,
    Map<String, Tenant> tenantById,
  ) {
    if (payments.isEmpty) {
      return _emptyState(context);
    }

    return Column(
      children: payments.map((payment) {
        final tenantName = tenantNameById[payment.tenantId] ?? 'Unknown';
        final propertyName = propertyNameById[payment.propertyId] ?? 'Unknown';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.pureWhite.withAlpha(130),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.liquidPrimaryStart.withAlpha(42),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenantName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Property: $propertyName'),
                    Text('Amount: Rs ${payment.amount}'),
                    Text('Due: ${_formatDate(payment.dueDate)}'),
                    const SizedBox(height: 6),
                    _statusChip(context, payment.status),
                    const SizedBox(height: 10),
                    if (payment.status == 'paid')
                      const Text('Paid')
                    else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              OwnerDashboardColors.managePropertiesActionColor(
                                context,
                              ),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => _showPaymentActions(
                          payment,
                          tenantById[payment.tenantId],
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 16),
                        label: const Text('Collect Payment'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'paid':
        bg = AppTheme.successGreen.withAlpha(26);
        fg = AppTheme.successGreen;
        break;
      case 'overdue':
        bg = AppTheme.errorRed.withAlpha(24);
        fg = AppTheme.errorRed;
        break;
      default:
        bg = AppTheme.warningAmber.withAlpha(30);
        fg = AppTheme.warningAmber;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite.withAlpha(120),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.liquidPrimaryStart.withAlpha(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: OwnerDashboardColors.managePropertiesHeaderSecondary(
              context,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No payments found for selected filters',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context, String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: _errorCard(context, message),
    );
  }

  Widget _errorCard(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorRed.withAlpha(90)),
      ),
      child: Text(
        'Error: $message',
        style: const TextStyle(
          color: AppTheme.errorRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showPaymentActions(Payment payment, Tenant? tenant) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.pureWhite.withAlpha(225),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: AppTheme.liquidPrimaryStart.withAlpha(50),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.liquidPrimaryStart.withAlpha(100),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      title: const Text('Collect Payment'),
                      subtitle: Text(
                        tenant != null
                            ? '${tenant.fullName} - Rs ${payment.amount}'
                            : 'Rs ${payment.amount}',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.payments_rounded),
                      title: const Text('Cash (Manual)'),
                      subtitle: const Text('Mark payment as paid by cash'),
                      onTap: () => Navigator.pop(sheetContext, 'cash'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_rounded),
                      title: const Text('Online (Manual Ref)'),
                      subtitle: const Text('Add optional transaction id'),
                      onTap: () => Navigator.pop(sheetContext, 'online-manual'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    try {
      if (action == 'cash') {
        await ref.read(markPaymentPaidCashUseCaseProvider).call(payment.id);
      } else if (action == 'online-manual') {
        final txId = await _askTransactionId();
        if (!mounted) return;
        await ref
            .read(markPaymentPaidOnlineUseCaseProvider)
            .call(
              payment.id,
              transactionId: txId?.trim().isEmpty ?? true ? null : txId,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment updated'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<String?> _askTransactionId() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Transaction ID (Optional)'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter transaction/reference id',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _exportCurrentView() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export ready: integrate CSV/PDF pipeline in next step.'),
      ),
    );
  }

  List<String> _buildMonthOptions(List<Payment> payments) {
    final keys = payments
        .map(
          (payment) => payment.periodKey.isNotEmpty
              ? payment.periodKey
              : _monthKey(payment.dueDate),
        )
        .toSet()
        .toList();
    keys.sort((a, b) => b.compareTo(a));
    return ['All Months', ...keys];
  }

  List<DropdownMenuItem<String>> _buildPropertyOptions(
    List<Property> properties,
  ) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Properties')),
    ];
    items.addAll(
      properties.map(
        (property) =>
            DropdownMenuItem(value: property.id, child: Text(property.name)),
      ),
    );
    return items;
  }

  List<DropdownMenuItem<String>> _buildTenantOptions(List<Tenant> tenants) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Tenants')),
    ];
    items.addAll(
      tenants.map(
        (tenant) =>
            DropdownMenuItem(value: tenant.id, child: Text(tenant.fullName)),
      ),
    );
    return items;
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthShort(date.month)} ${date.year}';
  }

  String _monthShort(int month) {
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
    return months[(month - 1).clamp(0, 11)];
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'overdue':
        return 'Overdue';
      default:
        return 'Pending';
    }
  }

  String _normalizeStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'overdue':
        return 'Overdue';
      default:
        return 'All';
    }
  }

  Widget _liquidBlob({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required bool isDark,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? AppTheme.liquidPrimaryStart.withAlpha(22)
              : AppTheme.liquidPrimaryStart.withAlpha(34),
        ),
      ),
    );
  }
}
