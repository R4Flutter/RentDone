import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/providers/tenant_payment_history_provider.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/tenant_card.dart';

class OwnerPaymentTenantListScreen extends ConsumerWidget {
  const OwnerPaymentTenantListScreen({
    super.key,
    required this.propertyId,
    this.propertyName,
  });

  final String propertyId;
  final String? propertyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(ownerPropertyTenantsProvider(propertyId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          propertyName?.trim().isNotEmpty == true
              ? propertyName!.trim()
              : 'Tenants',
          style: TextStyle(color: OwnerDashboardColors.textPrimary(context)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerPropertyTenantsProvider(propertyId));
        },
        child: tenantsAsync.when(
          loading: () => const _TenantSkeletonLoader(),
          error: (error, _) => _TenantListError(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(ownerPropertyTenantsProvider(propertyId)),
          ),
          data: (tenants) {
            if (tenants.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 140),
                  Center(
                    child: Text('No tenants available for this property.'),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: tenants.length,
              separatorBuilder: (_, idx) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tenant = tenants[index];
                return RepaintBoundary(
                  child: TenantCard(
                    tenant: tenant,
                    onTap: () {
                      context.goNamed(
                        'ownerTenantPaymentHistory',
                        pathParameters: {
                          'propertyId': propertyId,
                          'tenantId': tenant.id,
                        },
                        queryParameters: {
                          'propertyName': propertyName ?? '',
                          'tenantName': tenant.name,
                          'roomNumber': tenant.roomNumber,
                          'rentAmount': tenant.rentAmount.toString(),
                          'phone': tenant.phone,
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TenantListError extends StatelessWidget {
  const _TenantListError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 40),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}

/// Shimmer skeleton loader for tenant list.
class _TenantSkeletonLoader extends StatefulWidget {
  const _TenantSkeletonLoader();

  @override
  State<_TenantSkeletonLoader> createState() => _TenantSkeletonLoaderState();
}

class _TenantSkeletonLoaderState extends State<_TenantSkeletonLoader>
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: baseColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 12,
                              width: 120,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 10,
                              width: 80,
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
