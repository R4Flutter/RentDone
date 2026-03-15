import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/payment/data/gateways/cashfree_service.dart';
import 'package:rentdone/features/payment/data/gateways/payment_gateway.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/owner/owner_subscription/presentation/providers/subscription_provider.dart';

class OwnerSubscriptionScreen extends ConsumerWidget {
  const OwnerSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final tenantCountAsync = ref.watch(tenantListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (subscription) {
          final tenantsUsed = tenantCountAsync.maybeWhen(
            data: (count) => count,
            orElse: () => subscription.currentTenantCount,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CurrentPlanCard(
                  planTitle: subscription.planConfig.title,
                  paymentStatus: subscription.paymentStatus,
                  tenantLimit: subscription.tenantLimit,
                  tenantsUsed: tenantsUsed,
                  isActive: subscription.isActive,
                ),
                const SizedBox(height: 18),
                Text(
                  'Choose Your Plan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...subscriptionPlans.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCard(
                      plan: plan,
                      isCurrent: plan.code == subscription.subscriptionPlan,
                      onTap: () => _onPlanSelected(context, ref, plan),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    context.pushNamed('ownerPayments');
                  },
                  icon: const Icon(Icons.payment_rounded),
                  label: const Text('Payment History (Cashfree)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _onPlanSelected(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlanConfig plan,
  ) async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      final ownerId = auth.currentUser?.uid;

      if (ownerId == null || ownerId.isEmpty) {
        if (!context.mounted) return;
        _showError(context, 'Please sign in again.');
        return;
      }

      await ref
          .read(ownerSubscriptionServiceProvider)
          .ensureOwnerSubscriptionDoc(
            ownerId: ownerId,
            email: auth.currentUser?.email ?? '',
          );

      if (plan.code == 'free') {
        await ref
            .read(ownerSubscriptionServiceProvider)
            .activateFreePlan(ownerId: ownerId);

        ref.invalidate(subscriptionProvider);
        ref.invalidate(tenantListProvider);

        if (!context.mounted) return;
        _showSuccess(context, 'Free plan activated successfully!');
        return;
      }

      if (!context.mounted) return;
      _showPaymentDialog(context, ref, plan);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Error: ${e.toString()}');
    }
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlanConfig plan,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PaymentDialog(
        plan: plan,
        onPaymentCompleted: () {
          Navigator.pop(dialogContext);
          ref.invalidate(subscriptionProvider);
          ref.invalidate(tenantListProvider);
          _showSuccess(context, '${plan.title} plan activated successfully!');
        },
        onPaymentFailed: (reason) {
          Navigator.pop(dialogContext);
          _showError(context, reason);
        },
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _PaymentDialog extends ConsumerStatefulWidget {
  final SubscriptionPlanConfig plan;
  final VoidCallback onPaymentCompleted;
  final Function(String) onPaymentFailed;

  const _PaymentDialog({
    required this.plan,
    required this.onPaymentCompleted,
    required this.onPaymentFailed,
  });

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initiatePayment();
  }

  Future<void> _initiatePayment() async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      final service = ref.read(ownerSubscriptionServiceProvider);

      if (!mounted) return;
      setState(() => _isProcessing = true);

      final intent = await service.createSubscriptionPaymentIntent(
        plan: widget.plan,
      );

      if (!mounted) return;

      final ownerPhoneRaw = auth.currentUser?.phoneNumber ?? '';
      final ownerPhone = ownerPhoneRaw.replaceAll(RegExp(r'\D'), '');
      final normalizedPhone = ownerPhone.length >= 10
          ? ownerPhone.substring(ownerPhone.length - 10)
          : '9999999999';

      final result = await CashfreeService(isSandbox: false).initializePayment(
        PaymentGatewayRequest(
          orderId: intent.orderId,
          gatewayKey: intent.keyId,
          amount: intent.amountInPaise,
          currency: intent.currency,
          paymentId: intent.paymentId,
          tenantEmail: auth.currentUser?.email ?? 'owner@rentdone.app',
          tenantPhone: normalizedPhone,
          paymentSessionId: intent.paymentSessionId,
        ),
      );

      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() {
          _isProcessing = false;
          _errorMessage = result.failureReason ?? 'Payment failed';
        });
        return;
      }

      await service.verifySubscriptionPayment(paymentId: intent.paymentId);

      if (!mounted) return;
      widget.onPaymentCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Payment Failed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(_errorMessage!),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onPaymentFailed(_errorMessage!),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Processing Payment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Please complete the ${widget.plan.title} plan payment.\n'
              'Amount: ₹${widget.plan.monthlyPrice}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              _isProcessing ? 'Loading...' : 'Ready',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.planTitle,
    required this.paymentStatus,
    required this.tenantLimit,
    required this.tenantsUsed,
    required this.isActive,
  });

  final String planTitle;
  final String paymentStatus;
  final int tenantLimit;
  final int tenantsUsed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final ratio = tenantLimit <= 0
        ? 0.0
        : (tenantsUsed / tenantLimit).clamp(0, 1).toDouble();
    final scheme = Theme.of(context).colorScheme;

    Color statusColor = isActive && paymentStatus == 'active'
        ? AppColors.green
        : paymentStatus == 'pending'
        ? AppColors.orange
        : AppColors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded),
              const SizedBox(width: 8),
              Text(
                'Current Plan: $planTitle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Status: '),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  paymentStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Usage: $tenantsUsed / $tenantLimit tenants'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(value: ratio, minHeight: 10),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onTap,
  });

  final SubscriptionPlanConfig plan;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isCurrent ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? scheme.primary.withValues(alpha: 0.15)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(isCurrent ? 'Current' : 'Available'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.monthlyPrice == 0 ? 'Free' : '₹${plan.monthlyPrice}/month',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text('${plan.tenantLimit} tenants included'),
            const SizedBox(height: 6),
            Text(plan.description),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrent ? null : onTap,
                child: Text(
                  isCurrent ? 'Current Plan' : 'Choose ${plan.title}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
