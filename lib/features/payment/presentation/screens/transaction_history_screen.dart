import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
import 'package:rentdone/features/payment/presentation/widgets/payment_badge.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HistoryError(
          error: error,
          onRetry: () => ref
              .read(transactionHistoryProvider.notifier)
              .loadInitial(actor: widget.actor, actorId: widget.actorId),
        ),
        data: (data) {
          return Column(
            children: [
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
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemBuilder: (context, index) {
                      if (index == data.transactions.length) {
                        return _LoadMoreTile(
                          hasMore: data.hasMore,
                          isLoadingMore: data.isLoadingMore,
                          onLoadMore: () => ref
                              .read(transactionHistoryProvider.notifier)
                              .loadMore(),
                        );
                      }

                      final tx = data.transactions[index];
                      return _TransactionTile(transaction: tx);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
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
    final years = _yearOptions();
    final statuses = ['all', 'success', 'failed', 'pending', 'refunded'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          DropdownButton<int?>(
            value: selectedYear,
            hint: const Text('Year'),
            items: years
                .map(
                  (year) => DropdownMenuItem(
                    value: year,
                    child: Text(year == null ? 'All Years' : year.toString()),
                  ),
                )
                .toList(),
            onChanged: onYearChanged,
          ),
          DropdownButton<String>(
            value: selectedStatus,
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatCurrency(transaction.amount),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                PaymentBadge(
                  label: transaction.status.toUpperCase(),
                  status: transaction.status,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Gateway: ${transaction.gateway}'),
            const SizedBox(height: 4),
            Text('Transaction ID: ${transaction.transactionId}'),
            const SizedBox(height: 4),
            Text('Date: ${_formatDate(transaction.createdAt)}'),
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
            style: Theme.of(context).textTheme.titleLarge,
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
        child: Center(child: Text('No more transactions')),
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
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
