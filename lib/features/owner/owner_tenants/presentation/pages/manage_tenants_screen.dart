import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_tenants/presentation/providers/owner_tenants_provider.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';

class ManageTenantsScreen extends ConsumerWidget {
  const ManageTenantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

          if (tenants.isEmpty) {
            return Center(
              child: Text('No tenants yet', style: theme.textTheme.titleMedium),
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
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
                  Text(tenant.phone, style: theme.textTheme.bodySmall),
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
            if (tenant.documentUrls.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _viewDocuments(context, tenant),
                icon: const Icon(Icons.description, size: 16),
                label: Text('${tenant.documentUrls.length} Docs'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  void _viewDocuments(BuildContext context, Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${tenant.fullName} - Documents'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tenant.documentUrls.length,
            itemBuilder: (context, index) {
              final url = tenant.documentUrls[index];
              return ListTile(
                leading: const Icon(Icons.image),
                title: Text('Document ${index + 1}'),
                onTap: () {
                  // For now, show URL. In production, open in viewer
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening document: $url')),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
