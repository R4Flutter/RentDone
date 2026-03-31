import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:rentdone/app/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/owner/owner_tenants/presentation/providers/owner_tenants_provider.dart';
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
  ProviderSubscription<OrphanTenantCleanupState>? _cleanupSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupSubscription = ref.listenManual(orphanTenantCleanupProvider, (
        prev,
        next,
      ) {
        if (!mounted) return;
        if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
          ref.read(orphanTenantCleanupProvider.notifier).clearResult();
          return;
        }
        if (next.cleanedCount != null) {
          if (next.cleanedCount! > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Removed ${next.cleanedCount} orphan tenant records.',
                ),
              ),
            );
          }
          ref.read(orphanTenantCleanupProvider.notifier).clearResult();
        }
      });

      ref.read(orphanTenantCleanupProvider.notifier).cleanup();
    });
  }

  @override
  void dispose() {
    _cleanupSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(ownerTenantsProvider);
    final propertiesAsync = ref.watch(ownerTenantPropertiesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: OwnerDashboardColors.pageBackground(context),
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
          Positioned(
            top: -80,
            left: -40,
            child: _liquidBlob(
              210,
              OwnerDashboardColors.ownerTopBlobColor(context),
            ),
          ),
          Positioned(
            bottom: -110,
            right: -40,
            child: _liquidBlob(
              250,
              OwnerDashboardColors.ownerBottomBlobColor(context),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Manage Tenants',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: OwnerDashboardColors.textPrimary(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tenant Trust Search',
                        onPressed: () =>
                            context.push('/owner/tenants/trust-search'),
                        icon: Icon(
                          Icons.manage_search_rounded,
                          color: OwnerDashboardColors.iconPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: tenantsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (tenants) {
                        return propertiesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) =>
                              Center(child: Text('Property load error: $e')),
                          data: (properties) {
                            final propertyNameById = {
                              for (final p in properties) p.id: p.name,
                            };

                            final visibleTenants = tenants
                                .where((t) => !dismissedIds.contains(t.id))
                                .toList();

                            if (visibleTenants.isEmpty) {
                              return Center(
                                child: Text(
                                  'No tenants yet',
                                  style: theme.textTheme.titleMedium,
                                ),
                              );
                            }

                            // Group tenants by property name
                            final Map<String, List<Tenant>> grouped = {};
                            for (final t in visibleTenants) {
                              final name =
                                  propertyNameById[t.propertyId] ??
                                  'Unassigned';
                              grouped.putIfAbsent(name, () => []).add(t);
                            }

                            // Build flat list: property header string + tenant objects
                            final List<Object> items = [];
                            for (final entry in grouped.entries) {
                              items.add(entry.key);
                              items.addAll(entry.value);
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(
                                top: 6,
                                bottom: 12,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                if (item is String) {
                                  return _propertyHeader(context, theme, item);
                                }
                                final tenant = item as Tenant;
                                final isOrphan = !propertyNameById.containsKey(
                                  tenant.propertyId,
                                );
                                final propertyName =
                                    propertyNameById[tenant.propertyId] ??
                                    'Unassigned';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _tenantCard(
                                    context,
                                    theme,
                                    tenant,
                                    propertyName,
                                    isOrphan: isOrphan,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _propertyHeader(BuildContext context, ThemeData theme, String name) {
    final brand = OwnerDashboardColors.brandPrimary(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          Icon(Icons.home_work_rounded, size: 17, color: brand),
          const SizedBox(width: 7),
          Text(
            name,
            style: theme.textTheme.titleSmall?.copyWith(
              color: OwnerDashboardColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: OwnerDashboardColors.border(context),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _liquidBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, AppColors.transparent]),
      ),
    );
  }

  Widget _tenantCard(
    BuildContext context,
    ThemeData theme,
    Tenant tenant,
    String propertyName, {
    required bool isOrphan,
  }) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (isDark ? AppColors.white : AppColors.cFFFFFFFF).withValues(
                  alpha: isDark ? 0.15 : 0.80,
                ),
                OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: isDark ? 0.08 : 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OwnerDashboardColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                            color: isOrphan
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                        ),
                        if (isOrphan) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Orphan record',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brand,
                        side: BorderSide(color: brand.withValues(alpha: 0.45)),
                      ),
                      onPressed: () => _viewDocuments(context, tenant),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('View Documents'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: isDark
                            ? AppColors.white
                            : AppColors.cFF0F172A,
                      ),
                      onPressed: isOrphan
                          ? null
                          : () => _viewPayments(context, tenant, propertyName),
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
        child: SizedBox(
          width: 700,
          height: 560,
          child: Column(
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
                                      color: AppColors.grey[300],
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
