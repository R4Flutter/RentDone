import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/owner/owner_subscription/presentation/providers/subscription_provider.dart';

class OwnerSubscriptionScreen extends ConsumerWidget {
  const OwnerSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subscriptionAsync = ref.watch(subscriptionProvider);

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
          _liquidBlob(top: -90, left: -60, size: 300, isDark: isDark),
          _liquidBlob(bottom: -100, right: -70, size: 260, isDark: isDark),
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
                        child: Center(child: CircularProgressIndicator()),
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
                AppTheme.liquidPrimaryStart.withAlpha(220),
                AppTheme.liquidPrimaryEnd.withAlpha(200),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.white.withAlpha(46),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.white,
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
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current: ${currentPlan.toUpperCase()} • ${status.toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withAlpha(220),
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
              color: AppTheme.liquidPrimaryStart.withAlpha(44),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tenant Usage',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                    context,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: subscription.usageRatio,
                minHeight: 9,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: AppTheme.liquidPrimaryStart.withAlpha(36),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.liquidPrimaryEnd,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${subscription.currentTenantCount} of ${subscription.tenantLimit} tenants used',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                    context,
                  ),
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
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);
    final isCurrent = plan.code == currentPlanCode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppTheme.liquidPrimaryStart.withAlpha(44)
                : AppTheme.pureWhite.withAlpha(125),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.liquidPrimaryEnd
                  : AppTheme.liquidPrimaryStart.withAlpha(42),
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
                  color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                    context,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                plan.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                    context,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                plan.monthlyPrice == 0
                    ? 'Free'
                    : 'Rs ${plan.monthlyPrice}/month',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.liquidPrimaryEnd,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Limit: ${plan.tenantLimit} tenants',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                    context,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton(
                  onPressed: isCurrent ? null : onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.liquidPrimaryEnd,
                    disabledBackgroundColor: AppTheme.liquidPrimaryEnd
                        .withAlpha(90),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(isCurrent ? 'Current Plan' : 'Select Plan'),
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
      if (plan.code == 'free') {
        await service.activateFreePlan(ownerId: ownerId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Free plan activated successfully.')),
        );
      } else {
        await service.ensureOwnerSubscriptionDoc(
          ownerId: ownerId,
          email: email,
        );
        final intent = await service.createSubscriptionPaymentIntent(
          plan: plan,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment intent created. Order: ${intent.orderId}. Continue in payment flow.',
            ),
          ),
        );
      }
      ref.invalidate(subscriptionProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
              ? AppTheme.liquidPrimaryStart.withAlpha(22)
              : AppTheme.liquidPrimaryStart.withAlpha(32),
        ),
      ),
    );
  }
}
