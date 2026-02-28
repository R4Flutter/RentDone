import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/payment/presentation/widgets/payment_badge.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final TransactionActor actor;
  final String? actorId;

  const TransactionHistoryScreen({
    super.key,
    this.actor = TransactionActor.tenant,
    this.actorId,
  });

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(transactionHistoryProvider.notifier)
          .loadInitial(actor: widget.actor, actorId: widget.actorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryProvider);
    final data = state.asData?.value ?? TransactionHistoryState.initial();
    final showBlockingError = state.hasError && state.asData == null;
    final showInitialLoader = state.isLoading && data.transactions.isEmpty;
    final isTenant = widget.actor == TransactionActor.tenant;
    final summaryAsync = ref.watch(tenantDashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.nearBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.nearBlack,
        title: Text(isTenant ? 'Payments' : 'Transactions'),
      ),
      body: showBlockingError
          ? _HistoryError(
              error: state.error ?? 'Unable to load transactions',
              onRetry: () => ref
                  .read(transactionHistoryProvider.notifier)
                  .loadInitial(
                    actor: widget.actor,
                    actorId: widget.actorId,
                    force: true,
                  ),
            )
          : Builder(
              builder: (_) {
                final latestAmount = data.transactions.isEmpty
                    ? 0
                    : data.transactions.first.amount;
                final suggestedAmount = summaryAsync.maybeWhen(
                  data: (summary) {
                    if (summary.dueAmount > 0) {
                      return summary.dueAmount;
                    }
                    if (summary.monthlyRent > 0) {
                      return summary.monthlyRent;
                    }
                    return latestAmount;
                  },
                  orElse: () => latestAmount,
                );

                final ownerDetailsAsync = summaryAsync.maybeWhen(
                  data: (summary) => summary.tenantId.isEmpty
                      ? const AsyncValue<TenantOwnerDetails?>.data(null)
                      : ref.watch(tenantOwnerDetailsProvider(summary.tenantId)),
                  orElse: () => const AsyncValue<TenantOwnerDetails?>.loading(),
                );

                final ownerUpiId = ownerDetailsAsync.maybeWhen(
                  data: (details) => details?.ownerUpiId ?? '',
                  orElse: () => '',
                );

                final ownerName = ownerDetailsAsync.maybeWhen(
                  data: (details) {
                    final preferredName = (details?.ownerName ?? '').trim();
                    if (preferredName.isNotEmpty) {
                      return preferredName;
                    }
                    return summaryAsync.maybeWhen(
                      data: (summary) => summary.propertyName,
                      orElse: () => 'Owner',
                    );
                  },
                  orElse: () => 'Owner',
                );

                return Column(
                  children: [
                    if (isTenant)
                      _TenantPaymentHero(
                        latestAmount: suggestedAmount,
                        ownerUpiId: ownerUpiId,
                        ownerName: ownerName,
                      ),
                    _FilterBar(
                      selectedYear: data.selectedYear,
                      selectedStatus: data.selectedStatus,
                      onYearChanged: (year) => ref
                          .read(transactionHistoryProvider.notifier)
                          .setFilters(year: year),
                      onStatusChanged: (status) => ref
                          .read(transactionHistoryProvider.notifier)
                          .setFilters(status: status),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(transactionHistoryProvider.notifier)
                              .refresh();
                        },
                        child: showInitialLoader
                            ? const _TransactionListSkeleton()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  120,
                                ),
                                itemBuilder: (context, index) {
                                  if (index == data.transactions.length) {
                                    return _LoadMoreTile(
                                      hasMore: data.hasMore,
                                      isLoadingMore: data.isLoadingMore,
                                      onLoadMore: () => ref
                                          .read(
                                            transactionHistoryProvider.notifier,
                                          )
                                          .loadMore(),
                                    );
                                  }

                                  final tx = data.transactions[index];
                                  return _TransactionTile(transaction: tx);
                                },
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 16),
                                itemCount: data.transactions.length + 1,
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _TransactionListSkeleton extends StatelessWidget {
  const _TransactionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => Container(
        height: 128,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final int? selectedYear;
  final String selectedStatus;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<String> onStatusChanged;

  const _FilterBar({
    required this.selectedYear,
    required this.selectedStatus,
    required this.onYearChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final years = _yearOptions();
    final statuses = ['all', 'success', 'failed', 'pending', 'refunded'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          _DarkDropdown<int?>(
            value: selectedYear,
            hint: 'Year',
            items: years
                .map(
                  (year) => DropdownMenuItem<int?>(
                    value: year,
                    child: Text(year == null ? 'All Years' : year.toString()),
                  ),
                )
                .toList(),
            onChanged: onYearChanged,
          ),
          _DarkDropdown<String>(
            value: selectedStatus,
            hint: 'Status',
            items: statuses
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onStatusChanged(value);
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Intelligence History',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }

  List<int?> _yearOptions() {
    final now = DateTime.now().year;
    return [null, now, now - 1, now - 2];
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionRecord transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: AppTheme.nearBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatCurrency(transaction.amount),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                PaymentBadge(
                  label: transaction.status.toUpperCase(),
                  status: transaction.status,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Gateway: ${transaction.gateway}',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 4),
            Text(
              'Transaction ID: ${transaction.transactionId}',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${_formatDate(transaction.createdAt)}',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.75)),
            ),
            if (transaction.failureReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Failure: ${transaction.failureReason}',
                style: const TextStyle(color: AppTheme.errorRed),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    backgroundColor: AppTheme.nearBlack,
                    context: context,
                    builder: (_) =>
                        _TransactionDetailSheet(transaction: transaction),
                  );
                },
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  final TransactionRecord transaction;

  const _TransactionDetailSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Details',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Amount',
            value: _formatCurrency(transaction.amount),
          ),
          _DetailRow(label: 'Status', value: transaction.status),
          _DetailRow(label: 'Gateway', value: transaction.gateway),
          _DetailRow(label: 'Payment ID', value: transaction.paymentId),
          _DetailRow(label: 'Transaction ID', value: transaction.transactionId),
          _DetailRow(
            label: 'Created',
            value: _formatDate(transaction.createdAt),
          ),
          if (transaction.completedAt != null)
            _DetailRow(
              label: 'Completed',
              value: _formatDate(transaction.completedAt!),
            ),
          if (transaction.failureReason != null)
            _DetailRow(label: 'Failure', value: transaction.failureReason!),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreTile extends StatelessWidget {
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _LoadMoreTile({
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Center(
          child: Text(
            'No more transactions',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: OutlinedButton(
        onPressed: onLoadMore,
        child: const Text('Load more'),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _HistoryError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isOffline = error is NetworkFailure;
    final message = isOffline ? 'You are offline.' : error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isOffline ? Icons.wifi_off : Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _TenantPaymentHero extends StatefulWidget {
  final int latestAmount;
  final String ownerUpiId;
  final String ownerName;

  const _TenantPaymentHero({
    required this.latestAmount,
    required this.ownerUpiId,
    required this.ownerName,
  });

  @override
  State<_TenantPaymentHero> createState() => _TenantPaymentHeroState();
}

class _TenantPaymentHeroState extends State<_TenantPaymentHero> {
  late final TextEditingController _amountController;
  bool _isLaunchingUpi = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.latestAmount > 0 ? widget.latestAmount.toString() : '',
    );
  }

  @override
  void didUpdateWidget(covariant _TenantPaymentHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_amountController.text.trim().isEmpty && widget.latestAmount > 0) {
      _amountController.text = widget.latestAmount.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Map<String, String> _upiQuery({required int amount}) {
    final normalizedUpiId = widget.ownerUpiId.trim();
    if (normalizedUpiId.isEmpty) {
      return const {};
    }

    final payeeName = widget.ownerName.trim().isEmpty
        ? 'Owner'
        : widget.ownerName.trim();
    final amountValue = (amount <= 0 ? 1 : amount).toStringAsFixed(2);

    return {
      'pa': normalizedUpiId,
      'pn': payeeName,
      'am': amountValue,
      'cu': 'INR',
      'tn': 'Rent payment via RentDone',
    };
  }

  String _buildUpiUri({required int amount}) {
    final query = _upiQuery(amount: amount);
    if (query.isEmpty) {
      return '';
    }

    final uri = Uri(scheme: 'upi', host: 'pay', queryParameters: query);

    return uri.toString();
  }

  String _buildTezUri({required int amount}) {
    final query = _upiQuery(amount: amount);
    if (query.isEmpty) {
      return '';
    }

    final uri = Uri(
      scheme: 'tez',
      host: 'upi',
      path: '/pay',
      queryParameters: query,
    );

    return uri.toString();
  }

  Future<void> _openUpiApp(BuildContext context, {required int amount}) async {
    final upiUri = _buildUpiUri(amount: amount);
    if (upiUri.isEmpty || _isLaunchingUpi) {
      return;
    }

    setState(() => _isLaunchingUpi = true);

    final uriCandidates = <String>[
      _buildTezUri(amount: amount),
      upiUri,
    ].where((value) => value.isNotEmpty).toSet().toList();

    var opened = false;

    for (final raw in uriCandidates) {
      final uri = Uri.parse(raw);
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        continue;
      }
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (opened) {
        break;
      }
    }

    if (!opened) {
      opened = await launchUrl(
        Uri.parse(upiUri),
        mode: LaunchMode.externalApplication,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() => _isLaunchingUpi = false);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open UPI app. Check UPI app and owner UPI ID.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestAmount = widget.latestAmount;
    final enteredAmount =
        int.tryParse(_amountController.text.trim()) ?? latestAmount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppTheme.blueSurfaceGradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'RENTDONE UPI',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan & Pay Rent',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 142,
              height: 142,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Builder(
                builder: (context) {
                  final amount =
                      int.tryParse(_amountController.text.trim()) ?? 0;
                  final upiUri = _buildUpiUri(amount: amount);

                  if (upiUri.isEmpty) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'UPI not set',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  }

                  return QrImageView(
                    data: upiUri,
                    version: QrVersions.auto,
                    size: 126,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppTheme.nearBlack,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppTheme.nearBlack,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Enter amount (₹)',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
                hintText: latestAmount > 0
                    ? latestAmount.toString()
                    : 'Monthly amount',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.ownerUpiId.trim().isEmpty
                      ? 'Owner UPI not available'
                      : widget.ownerUpiId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateTime.now().month.toString().padLeft(2, '0') +
                      '/' +
                      DateTime.now().year.toString(),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLaunchingUpi
                    ? null
                    : () {
                        final amount =
                            int.tryParse(_amountController.text.trim()) ?? 0;
                        _openUpiApp(context, amount: amount);
                      },
                icon: _isLaunchingUpi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded, size: 16),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                ),
                label: Text(
                  _isLaunchingUpi
                      ? 'Opening payment app...'
                      : 'Pay with UPI (${_formatCurrency(enteredAmount)})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DarkDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.nearBlack.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        dropdownColor: AppTheme.nearBlack,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Colors.white),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

String _formatCurrency(int amount) {
  return 'Rs ${amount.toString()}';
}

String _formatDate(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
