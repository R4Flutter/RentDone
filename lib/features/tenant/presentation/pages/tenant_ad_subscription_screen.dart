import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/ads/tenant_ad_subscription_service.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_ad_subscription_provider.dart';

class TenantAdSubscriptionScreen extends ConsumerStatefulWidget {
  const TenantAdSubscriptionScreen({super.key});

  @override
  ConsumerState<TenantAdSubscriptionScreen> createState() =>
      _TenantAdSubscriptionScreenState();
}

class _TenantAdSubscriptionScreenState
    extends ConsumerState<TenantAdSubscriptionScreen> {
  late final Razorpay _razorpay;
  bool _isProcessing = false;
  TenantAdPlan? _activePlan;
  TenantAdSubscriptionPaymentIntent? _activeIntent;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final intent = _activeIntent;
    if (intent == null) {
      _setProcessing(false);
      return;
    }

    final orderId = (response.orderId ?? intent.orderId).trim();
    final paymentId = (response.paymentId ?? '').trim();
    final signature = (response.signature ?? '').trim();

    if (orderId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
      _setProcessing(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incomplete payment response from Razorpay.'),
        ),
      );
      return;
    }

    try {
      await ref
          .read(tenantAdSubscriptionServiceProvider)
          .verifySubscriptionPayment(
            subscriptionPaymentId: intent.subscriptionPaymentId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          );

      ref.invalidate(tenantAdSubscriptionProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_activePlan?.title ?? 'Subscription'} activated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${_friendlyError(error)}'),
        ),
      );
    } finally {
      _setProcessing(false);
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _setProcessing(false);
    if (!mounted) return;
    final message = (response.message ?? 'Payment failed').trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.isEmpty ? 'Payment failed.' : message)),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _setProcessing(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName ?? 'wallet'}',
        ),
      ),
    );
  }

  void _setProcessing(bool value) {
    if (!mounted) return;
    setState(() {
      _isProcessing = value;
      if (!value) {
        _activeIntent = null;
        _activePlan = null;
      }
    });
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return 'Something went wrong. Please try again.';
    return raw;
  }

  Future<void> _activate(TenantAdPlan plan) async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Subscription'),
          content: Text('Pay Rs ${plan.priceInr} to activate ${plan.title}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _activePlan = plan;
    });

    try {
      final intent = await ref
          .read(tenantAdSubscriptionServiceProvider)
          .createPaymentIntent(plan);

      _activeIntent = intent;

      _razorpay.open({
        'key': intent.keyId,
        'order_id': intent.orderId,
        'amount': intent.amountInPaise,
        'currency': intent.currency,
        'name': 'RentDone',
        'description': intent.planTitle,
        'notes': {
          'subscriptionPaymentId': intent.subscriptionPaymentId,
          'planCode': intent.planCode,
        },
      });
    } catch (error) {
      _setProcessing(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start payment: ${_friendlyError(error)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(tenantAdSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                  context,
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(tenantAdSubscriptionProvider);
                await ref.read(tenantAdSubscriptionProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Remove Ads Subscription',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: OwnerDashboardColors.cardBackground(
                            context,
                          ).withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: OwnerDashboardColors.border(context),
                          ),
                        ),
                        child: subscriptionAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) =>
                              Text('Could not load subscription: $error'),
                          data: (sub) {
                            if (sub.isActive) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ad-free is active',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Plan: ${sub.planCode.toUpperCase()}'),
                                  Text('Remaining days: ${sub.remainingDays}'),
                                ],
                              );
                            }

                            return const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Upgrade to remove ads',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Choose a plan and activate ad-free experience instantly.',
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PlanCard(
                    title: 'Rs 29 / month',
                    subtitle: 'Single month ad-free access',
                    plan: tenantAdMonthlyPlan,
                    isProcessing: _isProcessing,
                    onActivate: () => _activate(tenantAdMonthlyPlan),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    title: 'Rs 49 / 2 months',
                    subtitle: 'Best value plan for continuous ad-free use',
                    plan: tenantAdBiMonthlyPlan,
                    isProcessing: _isProcessing,
                    onActivate: () => _activate(tenantAdBiMonthlyPlan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.plan,
    required this.isProcessing,
    required this.onActivate,
  });

  final String title;
  final String subtitle;
  final TenantAdPlan plan;
  final bool isProcessing;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OwnerDashboardColors.cardBackground(
              context,
            ).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OwnerDashboardColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isProcessing ? null : onActivate,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(
                    isProcessing
                        ? 'Processing Payment...'
                        : 'Subscribe & Remove Ads',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
