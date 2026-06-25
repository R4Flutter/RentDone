import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/providers/tenant_payment_history_provider.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/property_card.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({
    super.key,
    this.initialStatus,
    this.initialTenantId,
    this.initialPropertyId,
    this.initialTenantName,
  });

  final String? initialStatus;
  final String? initialTenantId;
  final String? initialPropertyId;
  final String? initialTenantName;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _autoOpened = false;

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(ownerPaymentPropertiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerPaymentPropertiesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _Header(initialTenantName: widget.initialTenantName),
            const SizedBox(height: 16),
            propertiesAsync.when(
              loading: () => const _PaymentSkeletonLoader(),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(ownerPaymentPropertiesProvider),
              ),
              data: (properties) {
                if (!_autoOpened &&
                    (widget.initialPropertyId?.trim().isNotEmpty ?? false)) {
                  final match = properties.where(
                    (property) => property.id == widget.initialPropertyId,
                  );
                  if (match.isNotEmpty) {
                    _autoOpened = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      context.goNamed(
                        'ownerPaymentTenants',
                        pathParameters: {
                          'propertyId': widget.initialPropertyId!.trim(),
                        },
                        queryParameters: {'propertyName': match.first.name},
                      );
                    });
                  }
                }

                if (properties.isEmpty) {
                  return const _EmptyProperties();
                }

                return Column(
                  children: [
                    for (final property in properties) ...[
                      RepaintBoundary(
                        child: PropertyCard(
                          property: property,
                          onTap: () {
                            context.goNamed(
                              'ownerPaymentTenants',
                              pathParameters: {'propertyId': property.id},
                              queryParameters: {'propertyName': property.name},
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.initialTenantName});

  final String? initialTenantName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payments',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: OwnerDashboardColors.managePropertiesHeaderPrimary(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          initialTenantName?.trim().isNotEmpty == true
              ? 'Select a property to view ${initialTenantName!.trim()} payment timeline'
              : 'Select property, choose tenant, and view complete payment history.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OwnerDashboardColors.managePropertiesHeaderSecondary(
              context,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 90),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: AppTheme.errorRed,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: OwnerDashboardColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyProperties extends StatelessWidget {
  const _EmptyProperties();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Icon(Icons.apartment_outlined, size: 42),
          SizedBox(height: 8),
          Text('No properties found for this owner.'),
        ],
      ),
    );
  }
}

/// Shimmer skeleton loader shown while payment data loads.
/// Shows 3 placeholder cards with a pulse animation for perceived instant loading.
class _PaymentSkeletonLoader extends StatefulWidget {
  const _PaymentSkeletonLoader();

  @override
  State<_PaymentSkeletonLoader> createState() => _PaymentSkeletonLoaderState();
}

class _PaymentSkeletonLoaderState extends State<_PaymentSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Column(
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  height: 88,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 14,
                              width: 140,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 10,
                              width: 200,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(6),
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
          }),
        );
      },
    );
  }
}
