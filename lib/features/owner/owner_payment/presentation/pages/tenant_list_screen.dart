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
          loading: () => const Center(child: CircularProgressIndicator()),
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
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tenant = tenants[index];
                return TenantCard(
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
