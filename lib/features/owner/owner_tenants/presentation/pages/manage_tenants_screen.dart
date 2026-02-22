import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/owner/owner_tenants/presentation/providers/owner_tenants_provider.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';
import 'package:rentdone/shared/widgets/profile_picture_avatar.dart';

class ManageTenantsScreen extends ConsumerStatefulWidget {
  const ManageTenantsScreen({super.key});

  @override
  ConsumerState<ManageTenantsScreen> createState() =>
      _ManageTenantsScreenState();
}

class _ManageTenantsScreenState extends ConsumerState<ManageTenantsScreen> {
  final Set<String> dismissedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(ownerTenantsProvider);
    final propertiesAsync = ref.watch(ownerTenantPropertiesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tenants')),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tenants) {
          final properties = propertiesAsync.value ?? <Property>[];
          final propertyNameById = {for (final p in properties) p.id: p.name};

          // Filter out dismissed tenants
          final visibleTenants = tenants
              .where((t) => !dismissedIds.contains(t.id))
              .toList();

          if (visibleTenants.isEmpty) {
            return Center(
              child: Text('No tenants yet', style: theme.textTheme.titleMedium),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visibleTenants.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tenant = visibleTenants[index];
              final propertyName =
                  propertyNameById[tenant.propertyId] ?? 'Unknown Property';

              return _tenantCard(context, theme, tenant, propertyName);
            },
          );
        },
      ),
    );
  }

  Widget _tenantCard(
    BuildContext context,
    ThemeData theme,
    Tenant tenant,
    String propertyName,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircularProfileAvatar(
                  photoUrl: tenant.photoUrl,
                  email: tenant.email,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(tenant.phone, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        propertyName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewDocuments(context, tenant),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('View Documents'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _viewPayments(context, tenant, propertyName),
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                    ),
                    label: const Text('View Payments'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewDocuments(BuildContext context, Tenant tenant) {
    if (tenant.documentUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No documents uploaded for this tenant.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tenant.fullName} - Documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: tenant.documentUrls.map((url) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              height: 300,
                              width: double.maxFinite,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 300,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewPayments(BuildContext context, Tenant tenant, String propertyName) {
    context.goNamed(
      'ownerPayments',
      queryParameters: {
        'tenantId': tenant.id,
        'tenantName': tenant.fullName,
        'propertyId': tenant.propertyId,
      },
    );
  }
}
