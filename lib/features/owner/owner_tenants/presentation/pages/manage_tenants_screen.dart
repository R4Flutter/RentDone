import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/providers/property_tenant_provider.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';

class ManageTenantsScreen extends ConsumerWidget {
  const ManageTenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(allTenantsProvider);
    final propertiesAsync = ref.watch(allPropertiesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tenants')),
      body: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tenants) {
          final properties = propertiesAsync.value ?? <Property>[];
          final propertyNameById = {
            for (final p in properties) p.id: p.name,
          };

          if (tenants.isEmpty) {
            return Center(
              child: Text(
                'No tenants yet',
                style: theme.textTheme.titleMedium,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tenants.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tenant = tenants[index];
              final propertyName =
                  propertyNameById[tenant.propertyId] ?? 'Unknown Property';

              return _tenantCard(theme, tenant, propertyName);
            },
          );
        },
      ),
    );
  }

  Widget _tenantCard(ThemeData theme, Tenant tenant, String propertyName) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.person, color: Colors.blueGrey),
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
                  Text(
                    tenant.phone,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    propertyName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
