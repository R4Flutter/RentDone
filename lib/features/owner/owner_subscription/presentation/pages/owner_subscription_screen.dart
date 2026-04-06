import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/owner/owner_subscription/presentation/providers/subscription_provider.dart';
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

class OwnerSubscriptionScreen extends ConsumerStatefulWidget {
  const OwnerSubscriptionScreen({super.key});

  @override
  ConsumerState<OwnerSubscriptionScreen> createState() =>
      _OwnerSubscriptionScreenState();
}

class _OwnerSubscriptionScreenState
    extends ConsumerState<OwnerSubscriptionScreen> {
  late final Razorpay _razorpay;
  bool _isProcessing = false;
  OwnerSubscriptionPaymentIntent? _activeIntent;
  SubscriptionPlanConfig? _activePlan;

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
          .read(ownerSubscriptionServiceProvider)
          .verifySubscriptionPayment(
            paymentId: intent.paymentId,
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          );

      ref.invalidate(subscriptionProvider);
      ref.invalidate(tenantListProvider);

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

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final subscriptionAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
          _liquidBlob(
            context: context,
            top: -90,
            left: -60,
            size: 300,
            isDark: isDark,
          ),
          _liquidBlob(
            context: context,
            bottom: -100,
            right: -70,
            size: 260,
            isDark: isDark,
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(subscriptionProvider);
                await ref.read(subscriptionProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: subscriptionAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: 100),
                        child: Center(child: AppLoadingIndicator()),
                      ),
                      error: (error, _) =>
                          _errorCard(context, error.toString()),
                      data: (subscription) {
                        final plan = subscription.planConfig;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _header(
                              context,
                              plan.title,
                              subscription.paymentStatus,
                            ),
                            const SizedBox(height: 18),
                            _usageCard(context, subscription),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 900;
                                if (isWide) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _planCard(
                                          context,
                                          plan: freePlanConfig,
                                          currentPlanCode:
                                              subscription.subscriptionPlan,
                                          isBusy: _isProcessing,
                                          onSelect: () => _selectPlan(
                                            context,
                                            ref,
                                            freePlanConfig,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _planCard(
                                          context,
                                          plan: basicPlanConfig,
                                          currentPlanCode:
                                              subscription.subscriptionPlan,
                                          isBusy: _isProcessing,
                                          onSelect: () => _selectPlan(
                                            context,
                                            ref,
                                            basicPlanConfig,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _planCard(
                                          context,
                                          plan: proPlanConfig,
                                          currentPlanCode:
                                              subscription.subscriptionPlan,
                                          isBusy: _isProcessing,
                                          onSelect: () => _selectPlan(
                                            context,
                                            ref,
                                            proPlanConfig,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    _planCard(
                                      context,
                                      plan: freePlanConfig,
                                      currentPlanCode:
                                          subscription.subscriptionPlan,
                                      isBusy: _isProcessing,
                                      onSelect: () => _selectPlan(
                                        context,
                                        ref,
                                        freePlanConfig,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _planCard(
                                      context,
                                      plan: basicPlanConfig,
                                      currentPlanCode:
                                          subscription.subscriptionPlan,
                                      isBusy: _isProcessing,
                                      onSelect: () => _selectPlan(
                                        context,
                                        ref,
                                        basicPlanConfig,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _planCard(
                                      context,
                                      plan: proPlanConfig,
                                      currentPlanCode:
                                          subscription.subscriptionPlan,
                                      isBusy: _isProcessing,
                                      onSelect: () => _selectPlan(
                                        context,
                                        ref,
                                        proPlanConfig,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String currentPlan, String status) {
    final theme = Theme.of(context);
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final brandHover = OwnerDashboardColors.brandPrimaryHover(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final elevated = OwnerDashboardColors.elevatedBackground(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                brand.withValues(alpha: isDark ? 0.84 : 0.72),
                brandHover.withValues(alpha: isDark ? 0.9 : 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: OwnerDashboardColors.border(
                context,
              ).withValues(alpha: isDark ? 0.5 : 0.8),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: elevated.withValues(alpha: isDark ? 0.34 : 0.78),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current: ${currentPlan.toUpperCase()} • ${status.toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: OwnerDashboardColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _usageCard(BuildContext context, OwnerSubscriptionData subscription) {
    final theme = Theme.of(context);
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OwnerDashboardColors.activityCardBackground(
              context,
            ).withValues(alpha: isDark ? 0.78 : 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: OwnerDashboardColors.activityCardBorder(
                context,
              ).withValues(alpha: 0.9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tenant Usage',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OwnerDashboardColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: subscription.usageRatio,
                minHeight: 9,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: brand.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(
                  OwnerDashboardColors.brandPrimaryHover(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${subscription.currentTenantCount} of ${subscription.tenantLimit} tenants used',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context, {
    required SubscriptionPlanConfig plan,
    required String currentPlanCode,
    required bool isBusy,
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);
    final isCurrent = plan.code == currentPlanCode;
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final brandHover = OwnerDashboardColors.brandPrimaryHover(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? brand.withValues(alpha: isDark ? 0.22 : 0.14)
                : OwnerDashboardColors.cardBackground(
                    context,
                  ).withValues(alpha: isDark ? 0.76 : 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrent
                  ? brandHover
                  : OwnerDashboardColors.border(context).withValues(alpha: 0.9),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OwnerDashboardColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                plan.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                plan.monthlyPrice == 0
                    ? 'Free'
                    : 'Rs ${plan.monthlyPrice}/month',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: brandHover,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Limit: ${plan.tenantLimit} tenants',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton(
                  onPressed: (isCurrent || isBusy) ? null : onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: brandHover,
                    disabledBackgroundColor: brandHover.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isCurrent
                        ? 'Current Plan'
                        : (isBusy ? 'Processing...' : 'Select Plan'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPlan(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlanConfig plan,
  ) async {
    if (_isProcessing) return;

    final service = ref.read(ownerSubscriptionServiceProvider);
    final auth = ref.read(firebaseAuthProvider);
    final ownerId = auth.currentUser?.uid;
    final email = auth.currentUser?.email ?? '';

    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to manage subscription.')),
      );
      return;
    }

    try {
      _setProcessing(true);

      if (plan.code == 'free') {
        await service.activateFreePlan(ownerId: ownerId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Free plan activated successfully.')),
        );
        _setProcessing(false);
      } else {
        await service.ensureOwnerSubscriptionDoc(
          ownerId: ownerId,
          email: email,
        );
        final intent = await service.createSubscriptionPaymentIntent(
          plan: plan,
        );
        _activeIntent = intent;
        _activePlan = plan;

        _razorpay.open({
          'key': intent.keyId,
          'order_id': intent.orderId,
          'amount': intent.amountInPaise,
          'currency': intent.currency,
          'name': 'RentDone',
          'description': '${plan.title} Subscription',
          'prefill': {'email': email},
          'notes': {
            'subscriptionPaymentId': intent.paymentId,
            'planCode': plan.code,
          },
        });

        if (!context.mounted) return;
      }
      ref.invalidate(subscriptionProvider);
      ref.invalidate(tenantListProvider);
    } catch (error) {
      _setProcessing(false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Widget _errorCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withAlpha(80)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.errorRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _liquidBlob({
    required BuildContext context,
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required bool isDark,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.14)
              : OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.1),
        ),
      ),
    );
  }
}
