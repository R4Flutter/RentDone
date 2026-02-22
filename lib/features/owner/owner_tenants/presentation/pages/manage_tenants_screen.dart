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
  String? selectedPropertyId;

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

          visibleTenants.sort((a, b) {
            final propertyA =
                (propertyNameById[a.propertyId] ?? 'Unknown Property')
                    .toLowerCase();
            final propertyB =
                (propertyNameById[b.propertyId] ?? 'Unknown Property')
                    .toLowerCase();
            final propertyCompare = propertyA.compareTo(propertyB);
            if (propertyCompare != 0) return propertyCompare;

            return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          });

          if (visibleTenants.isEmpty) {
            return Center(
              child: Text('No tenants yet', style: theme.textTheme.titleMedium),
            );
          }

          final tenantsByPropertyId = <String, List<Tenant>>{};
          for (final tenant in visibleTenants) {
            tenantsByPropertyId
                .putIfAbsent(tenant.propertyId, () => [])
                .add(tenant);
          }

          final propertySections = tenantsByPropertyId.keys.toList()
            ..sort((a, b) {
              final nameA = (propertyNameById[a] ?? 'Unknown Property')
                  .toLowerCase();
              final nameB = (propertyNameById[b] ?? 'Unknown Property')
                  .toLowerCase();
              return nameA.compareTo(nameB);
            });

          final activePropertyId = _resolveSelectedPropertyId(propertySections);
          final filteredPropertySections = activePropertyId == null
              ? propertySections
              : propertySections.where((id) => id == activePropertyId).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPropertyFilterChips(
                theme,
                propertySections,
                tenantsByPropertyId,
                propertyNameById,
                activePropertyId,
              ),
              const SizedBox(height: 16),
              for (final propertyId in filteredPropertySections) ...[
                _buildPropertySectionHeader(
                  theme,
                  propertyNameById[propertyId] ?? 'Unknown Property',
                  tenantsByPropertyId[propertyId]?.length ?? 0,
                ),
                const SizedBox(height: 10),
                ...tenantsByPropertyId[propertyId]!.map(
                  (tenant) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _tenantCard(
                      context,
                      theme,
                      tenant,
                      propertyNameById[propertyId] ?? 'Unknown Property',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
          );
        },
      ),
    );
  }

  String? _resolveSelectedPropertyId(List<String> availablePropertyIds) {
    final currentSelection = selectedPropertyId;
    if (currentSelection == null) {
      return null;
    }
    if (availablePropertyIds.contains(currentSelection)) {
      return currentSelection;
    }
    return null;
  }

  Widget _buildPropertyFilterChips(
    ThemeData theme,
    List<String> propertySections,
    Map<String, List<Tenant>> tenantsByPropertyId,
    Map<String, String> propertyNameById,
    String? activePropertyId,
  ) {
    final totalTenants = tenantsByPropertyId.values.fold<int>(
      0,
      (sum, tenants) => sum + tenants.length,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('All ($totalTenants)'),
          selected: activePropertyId == null,
          selectedColor: theme.colorScheme.primaryContainer,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            setState(() => selectedPropertyId = null);
          },
        ),
        for (final propertyId in propertySections)
          ChoiceChip(
            label: Text(
              '${propertyNameById[propertyId] ?? 'Unknown Property'} (${tenantsByPropertyId[propertyId]?.length ?? 0})',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: activePropertyId == propertyId,
            selectedColor: theme.colorScheme.primaryContainer,
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            onSelected: (_) {
              setState(() => selectedPropertyId = propertyId);
            },
          ),
      ],
    );
  }

  Widget _buildPropertySectionHeader(
    ThemeData theme,
    String propertyName,
    int tenantCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.apartment_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              propertyName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$tenantCount tenants',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tenantCard(
    BuildContext context,
    ThemeData theme,
    Tenant tenant,
    String propertyName,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircularProfileAvatar(
                  photoUrl: tenant.photoUrl,
                  email: tenant.email,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tenant.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _buildStatusChip(theme, tenant.isActive),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tenant.phone,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 15,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              propertyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metaChip(
                            theme,
                            Icons.currency_rupee,
                            '₹${tenant.rentAmount}/month',
                          ),
                          if (tenant.rentDueDay > 0)
                            _metaChip(
                              theme,
                              Icons.event_outlined,
                              'Due ${tenant.rentDueDay}th',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Deposit',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${tenant.securityDeposit}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _viewDocuments(context, tenant),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Documents'),
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
                    label: const Text('Payments'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, bool isActive) {
    final foreground = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final background = isActive
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metaChip(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelMedium),
        ],
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
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
