import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_dashboard_provider.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_di.dart';
import 'package:rentdone/features/payment/presentation/screens/transaction_history_screen.dart';
import 'package:rentdone/features/payment/presentation/widgets/payment_badge.dart';

class TenantPaymentDashboardScreen extends ConsumerWidget {
  const TenantPaymentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rent Payments')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () =>
              ref.read(paymentDashboardProvider.notifier).refreshDue(),
        ),
        data: (data) {
          if (data.due == null) {
            return _EmptyState(
              onRefresh: () =>
                  ref.read(paymentDashboardProvider.notifier).refreshDue(),
            );
          }

          final due = data.due!;
          final isOverdue = due.daysRemaining < 0;
          final remainingLabel = isOverdue
              ? '${due.daysRemaining.abs()} days overdue'
              : '${due.daysRemaining} days remaining';
          final canPay =
              due.paymentStatus != 'paid' && due.paymentStatus != 'success';

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(paymentDashboardProvider.notifier).refreshDue();
            },
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _SummaryCard(
                  title: due.propertyName,
                  subtitle: 'Owner: ${due.ownerName}',
                  amount: due.totalPayable,
                  status: due.paymentStatus,
                  remaining: remainingLabel,
                  dueDate: due.dueDate,
                  rentAmount: due.monthlyRent,
                  lateFee: due.lateFeeAmount,
                  lastTransactionStatus: due.lastTransactionStatus,
                ),
                const SizedBox(height: 24),
                _ActionRow(
                  canPay: canPay,
                  onPayNow: () => _handlePayNow(context, ref),
                  onViewTransactions: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TransactionHistoryScreen(),
                      ),
                    );
                  },
                  onDownloadReceipt: () =>
                      _handleReceipt(context, due.receiptUrl),
                ),
                const SizedBox(height: 32),
                _DetailCard(due: due),
                if (data.message != null) ...[
                  const SizedBox(height: 16),
                  _InfoBanner(message: data.message!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handlePayNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(paymentDashboardProvider.notifier);
    final razorpay = ref.read(razorpayGatewayProvider);
    final user = FirebaseAuth.instance.currentUser;

    final intent = await notifier.createAndPay(
      gateway: 'razorpay',
      paymentGateway: razorpay,
      tenantEmail: user?.email ?? 'tenant@rentdone.app',
      tenantPhone: user?.phoneNumber ?? '0000000000',
    );

    if (intent == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment did not complete')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Payment verified successfully')),
    );
  }

  void _handleReceipt(BuildContext context, String? receiptUrl) {
    if (receiptUrl == null || receiptUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No receipt available yet')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt download coming soon')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int amount;
  final String status;
  final String remaining;
  final DateTime dueDate;
  final int rentAmount;
  final int lateFee;
  final String? lastTransactionStatus;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.remaining,
    required this.dueDate,
    required this.rentAmount,
    required this.lateFee,
    required this.lastTransactionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
                PaymentBadge(label: status.toUpperCase(), status: status),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _formatCurrency(amount),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              remaining,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: status.toLowerCase() == 'overdue'
                    ? AppTheme.errorRed
                    : AppTheme.warningAmber,
              ),
            ),
            const Divider(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _MetaItem(
                  label: 'Monthly Rent',
                  value: _formatCurrency(rentAmount),
                ),
                _MetaItem(label: 'Late Fee', value: _formatCurrency(lateFee)),
                _MetaItem(label: 'Due Date', value: _formatDate(dueDate)),
                _MetaItem(
                  label: 'Last Transaction',
                  value: lastTransactionStatus ?? 'None',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final PaymentDue due;

  const _DetailCard({required this.due});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Property', value: due.propertyName),
            _DetailRow(label: 'Owner', value: due.ownerName),
            _DetailRow(
              label: 'Monthly Rent',
              value: _formatCurrency(due.monthlyRent),
            ),
            _DetailRow(
              label: 'Late Fee',
              value: _formatCurrency(due.lateFeeAmount),
            ),
            _DetailRow(
              label: 'Total Payable',
              value: _formatCurrency(due.totalPayable),
            ),
            _DetailRow(label: 'Payment Status', value: due.paymentStatus),
            _DetailRow(
              label: 'Last Transaction',
              value: due.lastTransactionStatus ?? 'None',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool canPay;
  final VoidCallback onPayNow;
  final VoidCallback onViewTransactions;
  final VoidCallback onDownloadReceipt;

  const _ActionRow({
    required this.canPay,
    required this.onPayNow,
    required this.onViewTransactions,
    required this.onDownloadReceipt,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        FilledButton(
          onPressed: canPay ? onPayNow : null,
          child: const Text('Pay Now'),
        ),
        OutlinedButton(
          onPressed: onViewTransactions,
          child: const Text('View Transactions'),
        ),
        OutlinedButton(
          onPressed: onDownloadReceipt,
          child: const Text('Download Latest Receipt'),
        ),
      ],
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64),
            const SizedBox(height: 16),
            Text(
              'No payments due',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('We will notify you when the next rent is generated.'),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isOffline = error is NetworkFailure;
    final title = isOffline ? 'You are offline' : 'Something went wrong';
    final message = isOffline
        ? 'Check your connection and try again.'
        : error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isOffline ? Icons.wifi_off : Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
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
