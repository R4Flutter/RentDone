import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/providers/tenant_payment_history_provider.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/add_payment_form.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/payment_history_card.dart';

class TenantPaymentHistoryScreen extends ConsumerStatefulWidget {
  const TenantPaymentHistoryScreen({
    super.key,
    required this.propertyId,
    required this.tenantId,
    this.propertyName,
    this.tenantName,
    this.roomNumber,
    this.rentAmount,
    this.phone,
  });

  final String propertyId;
  final String tenantId;
  final String? propertyName;
  final String? tenantName;
  final String? roomNumber;
  final int? rentAmount;
  final String? phone;

  @override
  ConsumerState<TenantPaymentHistoryScreen> createState() =>
      _TenantPaymentHistoryScreenState();
}

class _TenantPaymentHistoryScreenState
    extends ConsumerState<TenantPaymentHistoryScreen> {
  static const int _pageSize = 20;

  final List<TenantPaymentRecord> _items = <TenantPaymentRecord>[];
  DateTime? _cursor;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _hasMore = true;
      _cursor = null;
    });

    try {
      final service = ref.read(tenantPaymentHistoryServiceProvider);
      final page = await service.fetchTenantPayments(
        tenantId: widget.tenantId,
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load payment history. Pull to retry.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final service = ref.read(tenantPaymentHistoryServiceProvider);
      final page = await service.fetchTenantPayments(
        tenantId: widget.tenantId,
        limit: _pageSize,
        cursor: _cursor,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _error = 'Unable to load more payments. Try again.';
      });
    }
  }

  Future<void> _addPayment(AddPaymentPayload payload) async {
    final service = ref.read(tenantPaymentHistoryServiceProvider);
    await service.addPayment(
      tenantId: widget.tenantId,
      propertyId: widget.propertyId,
      amount: payload.amount,
      date: payload.date,
      method: payload.method,
      status: payload.status,
      notes: payload.notes,
    );
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Tenant Payment History'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Payment'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 120 &&
                _hasMore &&
                !_isLoadingMore) {
              _loadMore();
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
            children: [
              _SummaryCard(
                propertyName: widget.propertyName,
                tenantName: widget.tenantName,
                roomNumber: widget.roomNumber,
                rentAmount: widget.rentAmount,
                phone: widget.phone,
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null && _items.isEmpty)
                _HistoryError(message: _error!, onRetry: _loadInitial)
              else if (_items.isEmpty)
                const _EmptyHistory()
              else
                ..._buildGroupedPayments(_items),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedPayments(List<TenantPaymentRecord> records) {
    final grouped = <String, List<TenantPaymentRecord>>{};

    for (final record in records) {
      final key = _monthKey(record.date);
      grouped.putIfAbsent(key, () => <TenantPaymentRecord>[]).add(record);
    }

    final monthKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final key in monthKeys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            key,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );

      final monthRecords = grouped[key]!
        ..sort((a, b) => b.date.compareTo(a.date));

      for (final record in monthRecords) {
        widgets.add(PaymentHistoryCard(payment: record));
        widgets.add(const SizedBox(height: 10));
      }
    }

    return widgets;
  }

  String _monthKey(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _showAddPaymentSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) {
        return AddPaymentForm(onSubmit: _addPayment);
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.propertyName,
    required this.tenantName,
    required this.roomNumber,
    required this.rentAmount,
    required this.phone,
  });

  final String? propertyName;
  final String? tenantName;
  final String? roomNumber;
  final int? rentAmount;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tenantName?.trim().isNotEmpty == true
                ? tenantName!.trim()
                : 'Tenant',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OwnerDashboardColors.textPrimary(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(context, 'Property: ${propertyName ?? 'NA'}'),
              _pill(context, 'Room: ${roomNumber ?? 'NA'}'),
              _pill(context, 'Monthly Rent: Rs ${rentAmount ?? 0}'),
              if ((phone ?? '').trim().isNotEmpty)
                _pill(context, 'Phone: ${phone!}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: OwnerDashboardColors.brandPrimary(
          context,
        ).withValues(alpha: OwnerDashboardColors.isDark(context) ? 0.10 : 0.06),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: OwnerDashboardColors.textPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 18,
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 18,
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 42),
          SizedBox(height: 8),
          Text(
            'No payment history available for this tenant.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
