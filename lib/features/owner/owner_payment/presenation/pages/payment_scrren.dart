import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';
import 'package:rentdone/features/owner/owner_payment/data/models/payment_model.dart';
import 'package:rentdone/features/owner/owner_payment/presenation/providers/payments_provider.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/providers/property_tenant_provider.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  final String? initialStatus;

  const PaymentsScreen({super.key, this.initialStatus});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String selectedMonth = 'All Months';
  String selectedPropertyId = 'all';
  late String selectedStatus;
  final TextEditingController searchCtrl = TextEditingController();
  late final Razorpay _razorpay;
  String? _activePaymentId;

  @override
  void initState() {
    super.initState();
    selectedStatus = _normalizeStatus(widget.initialStatus);
    _razorpay = Razorpay();
    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      setState(() {
        selectedStatus = _normalizeStatus(widget.initialStatus);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentsAsync = ref.watch(paymentsProvider);
    final propertiesAsync = ref.watch(allPropertiesProvider);
    final tenantsAsync = ref.watch(allTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rent Payments"),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text("Export Report"),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (payments) {
          final properties = propertiesAsync.value ?? <Property>[];
          final tenants = tenantsAsync.value ?? <Tenant>[];

          final propertyNameById = {
            for (final p in properties) p.id: p.name,
          };
          final tenantNameById = {
            for (final t in tenants) t.id: t.fullName,
          };
          final tenantById = {
            for (final t in tenants) t.id: t,
          };

          final monthOptions = _buildMonthOptions(payments);
          final propertyOptions = _buildPropertyOptions(properties);

          final effectiveMonth =
              monthOptions.contains(selectedMonth) ? selectedMonth : 'All Months';
          final effectivePropertyId = propertyOptions
                  .any((element) => element.value == selectedPropertyId)
              ? selectedPropertyId
              : 'all';

          final filteredPayments = payments.where((p) {
            final monthKey =
                p.periodKey.isNotEmpty ? p.periodKey : _monthKey(p.dueDate);
            if (effectiveMonth != 'All Months' &&
                monthKey != effectiveMonth) {
              return false;
            }
            if (effectivePropertyId != 'all' &&
                p.propertyId != effectivePropertyId) {
              return false;
            }
            if (selectedStatus != 'All' &&
                p.status != selectedStatus.toLowerCase()) {
              return false;
            }
            if (searchCtrl.text.trim().isNotEmpty) {
              final q = searchCtrl.text.trim().toLowerCase();
              final name = (tenantNameById[p.tenantId] ?? '').toLowerCase();
              if (!name.contains(q)) return false;
            }
            return true;
          }).toList();

          final expected =
              filteredPayments.fold<int>(0, (sum, p) => sum + p.amount);
          final collected = filteredPayments
              .where((p) => p.status == 'paid')
              .fold<int>(0, (sum, p) => sum + p.amount);
          final pending = filteredPayments
              .where((p) => p.status == 'pending')
              .fold<int>(0, (sum, p) => sum + p.amount);
          final overdue = filteredPayments
              .where((p) => p.status == 'overdue')
              .fold<int>(0, (sum, p) => sum + p.amount);
          final collectionRate =
              expected == 0 ? 0 : ((collected / expected) * 100).round();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1000;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1400 : double.infinity,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _filterBar(
                          monthOptions,
                          propertyOptions,
                          effectiveMonth,
                          effectivePropertyId,
                        ),
                        const SizedBox(height: 32),
                        _kpiSection(
                          theme,
                          expected,
                          collected,
                          pending,
                          overdue,
                          collectionRate,
                        ),
                        const SizedBox(height: 40),
                        isDesktop
                            ? _desktopTable(
                                theme,
                                filteredPayments,
                                propertyNameById,
                                tenantNameById,
                                tenantById,
                              )
                            : _mobileList(
                                theme,
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
    );
  }

  // ==========================================================
  // FILTER BAR
  // ==========================================================

  Widget _filterBar(
    List<String> monthOptions,
    List<DropdownMenuItem<String>> propertyOptions,
    String effectiveMonth,
    String effectivePropertyId,
  ) {
    return Wrap(
      spacing: 20,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        DropdownButton<String>(
          value: effectiveMonth,
          onChanged: (v) => setState(() => selectedMonth = v!),
          items: monthOptions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
        DropdownButton<String>(
          value: effectivePropertyId,
          onChanged: (v) => setState(() => selectedPropertyId = v!),
          items: propertyOptions,
        ),
        DropdownButton<String>(
          value: selectedStatus,
          onChanged: (v) => setState(() => selectedStatus = v!),
          items: const ["All", "Paid", "Pending", "Overdue"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            controller: searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search Tenant...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // KPI SECTION
  // ==========================================================

  Widget _kpiSection(
    ThemeData theme,
    int expected,
    int collected,
    int pending,
    int overdue,
    int collectionRate,
  ) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _kpiCard(theme, "Expected", "Rs $expected"),
        _kpiCard(theme, "Collected", "Rs $collected"),
        _kpiCard(theme, "Pending", "Rs $pending"),
        _kpiCard(theme, "Overdue", "Rs $overdue"),
        _kpiCard(theme, "Collection Rate", "$collectionRate%"),
      ],
    );
  }

  Widget _kpiCard(ThemeData theme, String title, String value) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.displayMedium),
        ],
      ),
    );
  }

  // ==========================================================
  // DESKTOP TABLE VIEW
  // ==========================================================

  Widget _desktopTable(
    ThemeData theme,
    List<Payment> payments,
    Map<String, String> propertyNameById,
    Map<String, String> tenantNameById,
    Map<String, Tenant> tenantById,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Tenant")),
          DataColumn(label: Text("Property")),
          DataColumn(label: Text("Amount")),
          DataColumn(label: Text("Due Date")),
          DataColumn(label: Text("Status")),
          DataColumn(label: Text("Action")),
        ],
        rows: payments.map((p) {
          final tenantName = tenantNameById[p.tenantId] ?? 'Unknown';
          final propertyName = propertyNameById[p.propertyId] ?? 'Unknown';
          return DataRow(cells: [
            DataCell(Text(tenantName)),
            DataCell(Text(propertyName)),
            DataCell(Text("Rs ${p.amount}")),
            DataCell(Text(_formatDate(p.dueDate))),
            DataCell(Text(_statusLabel(p.status))),
            DataCell(_actionCell(p, tenantById[p.tenantId]) as Widget),
          ]);
        }).toList(),
      ),
    );
  }

  DataCell _actionCell(Payment payment, Tenant? tenant) {
    if (payment.status == 'paid') {
      return const DataCell(Text("Paid"));
    }
    return DataCell(
      ElevatedButton(
        onPressed: () => _showPaymentActions(payment, tenant),
        child: const Text("Collect"),
      ),
    );
  }

  // ==========================================================
  // MOBILE LIST VIEW
  // ==========================================================

  Widget _mobileList(
    ThemeData theme,
    List<Payment> payments,
    Map<String, String> propertyNameById,
    Map<String, String> tenantNameById,
    Map<String, Tenant> tenantById,
  ) {
    if (payments.isEmpty) {
      return Text(
        "No payments found",
        style: theme.textTheme.bodyMedium,
      );
    }
    return Column(
      children: payments.map((p) {
        final tenantName = tenantNameById[p.tenantId] ?? 'Unknown';
        final propertyName = propertyNameById[p.propertyId] ?? 'Unknown';
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _paymentCard(
            theme,
            tenantName,
            propertyName,
            p,
            tenantById[p.tenantId],
          ),
        );
      }).toList(),
    );
  }

  Widget _paymentCard(
    ThemeData theme,
    String tenantName,
    String propertyName,
    Payment payment,
    Tenant? tenant,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tenantName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text("Property: $propertyName"),
          const SizedBox(height: 6),
          Text("Amount: Rs ${payment.amount}"),
          const SizedBox(height: 6),
          Text("Due: ${_formatDate(payment.dueDate)}"),
          const SizedBox(height: 6),
          Text("Status: ${_statusLabel(payment.status)}"),
          const SizedBox(height: 16),
          if (payment.status == 'paid')
            const Text("Paid")
          else
            ElevatedButton(
              onPressed: () => _showPaymentActions(payment, tenant),
              child: const Text("Collect"),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // MARK PAID FLOW
  // ==========================================================

  Future<void> _showPaymentActions(Payment payment, Tenant? tenant) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text("Collect Payment"),
              ),
              ListTile(
                leading: const Icon(Icons.payments_rounded),
                title: const Text("Cash (Manual)"),
                subtitle: const Text("Use for cash received"),
                onTap: () => Navigator.pop(c, 'cash'),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text("Online (Razorpay)"),
                subtitle: const Text("Accept online payment securely"),
                onTap: () => Navigator.pop(c, 'razorpay'),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card_rounded),
                title: const Text("Online (Manual Ref)"),
                subtitle: const Text("Use if payment came externally"),
                onTap: () => Navigator.pop(c, 'online-manual'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    try {
      if (action == 'cash') {
        await ref
            .read(paymentFirebaseServiceProvider)
            .markPaymentPaidCash(payment.id);
      } else if (action == 'online-manual') {
        final txId = await _askTransactionId();
        if (!mounted) return;
        await ref.read(paymentFirebaseServiceProvider).markPaymentPaidOnline(
              payment.id,
              transactionId: txId?.trim().isEmpty ?? true ? null : txId,
            );
      } else if (action == 'razorpay') {
        await _startRazorpayCheckout(payment, tenant);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment updated"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _askTransactionId() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text("Transaction ID (Optional)"),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: "Enter transaction/reference id",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Skip"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  // ==========================================================
  // RAZORPAY CHECKOUT
  // ==========================================================

  Future<void> _startRazorpayCheckout(Payment payment, Tenant? tenant) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createRazorpayOrder');
      final result = await callable.call({
        'paymentId': payment.id,
        'amount': payment.amount * 100, // Razorpay expects paise
        'currency': 'INR',
        'receipt': 'rent_${payment.id}',
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final orderId = data['orderId'] as String;
      final keyId = data['keyId'] as String;
      final amount = data['amount'] as int;
      final currency = data['currency'] as String;

      _activePaymentId = payment.id;

      _razorpay.open({
        'key': keyId,
        'amount': amount,
        'currency': currency,
        'name': 'RentDone',
        'description': 'Rent ${payment.periodKey.isNotEmpty ? payment.periodKey : _monthKey(payment.dueDate)}',
        'order_id': orderId,
        'prefill': {
          'contact': tenant?.phone ?? '',
          'email': tenant?.email ?? '',
        },
        'notes': {
          'paymentId': payment.id,
        },
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Razorpay error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePaymentSuccess(
    PaymentSuccessResponse response,
  ) async {
    final paymentId = _activePaymentId;
    _activePaymentId = null;
    if (paymentId == null) return;

    try {
      if (response.orderId == null ||
          response.paymentId == null ||
          response.signature == null) {
        throw Exception('Missing Razorpay response fields');
      }
      final callable =
          FirebaseFunctions.instance.httpsCallable('confirmRazorpayPayment');
      await callable.call({
        'paymentId': paymentId,
        'razorpayOrderId': response.orderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment confirmed"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _activePaymentId = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Payment failed: ${response.code} ${response.message ?? ''}",
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("External wallet: ${response.walletName ?? ''}"),
      ),
    );
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  List<String> _buildMonthOptions(List<Payment> payments) {
    final keys = payments
        .map((p) => p.periodKey.isNotEmpty ? p.periodKey : _monthKey(p.dueDate))
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
        (p) => DropdownMenuItem(
          value: p.id,
          child: Text(p.name),
        ),
      ),
    );
    return items;
  }

  String _monthKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    return '${date.year}-$m';
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
}
