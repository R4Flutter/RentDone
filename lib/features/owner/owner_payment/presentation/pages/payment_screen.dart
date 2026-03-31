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
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              ),
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
                      PropertyCard(
                        property: property,
                        onTap: () {
                          context.goNamed(
                            'ownerPaymentTenants',
                            pathParameters: {'propertyId': property.id},
                            queryParameters: {'propertyName': property.name},
                          );
                        },
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
