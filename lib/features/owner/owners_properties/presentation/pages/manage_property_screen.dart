import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/pages/owner_add_property.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/pages/add_property_screen.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/pages/property_detail_screen.dart';

import 'package:rentdone/features/owner/owners_properties/presentation/providers/property_tenant_provider.dart';

class ManagePropertiesScreen extends ConsumerWidget {
  const ManagePropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final propertiesAsync = ref.watch(allPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Properties"),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Add Property"),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1200 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                  vertical: 24,
                ),
                child: propertiesAsync.when(
                  data: (properties) {
                    if (properties.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.home_work_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No properties yet",
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Create your first property to get started",
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddPropertyScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Create Property"),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        final property = properties[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PropertyDetailScreen(
                                  propertyId: property.id,
                                ),
                              ),
                            );
                          },
                          child: _propertyCard(context, ref, theme, property),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stk) => Center(child: Text("Error: $err")),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _propertyCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    dynamic property,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property.address,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text("Edit"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddPropertyScreen(property: property),
                        ),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Text("Delete"),
                    onTap: () {
                      _confirmDelete(context, ref, property);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _statChip(theme, "Total Rooms", property.totalRooms.toString()),
              _statChip(theme, "Occupied", property.occupiedRooms.toString()),
              _statChip(theme, "Vacant", property.vacantRooms.toString()),
            ],
          ),
          if (property.rooms.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "Rooms",
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildRoomsList(context, ref, theme, property),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRoomsList(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    dynamic property,
  ) {
    return property.rooms.map<Widget>((room) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Room ${room.roomNumber}",
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    if (room.isOccupied && room.tenantId != null)
                      Expanded(
                        child: FutureBuilder<Tenant?>(
                          future: ref
                              .read(getTenantByIdUseCaseProvider)
                              .call(room.tenantId!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Text(
                                "Loading tenant...",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              );
                            }

                            final tenant = snapshot.data;
                            if (tenant == null) {
                              return Text(
                                "Occupied",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tenant.fullName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  tenant.phone,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((tenant.email ?? '').isNotEmpty)
                                  Text(
                                    tenant.email!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () {
                                        final route = Uri(
                                          path: '/owner/payments',
                                          queryParameters: {
                                            'tenantId': tenant.id,
                                            'propertyId': property.id,
                                            'tenantName': tenant.fullName,
                                          },
                                        ).toString();
                                        context.go(route);
                                      },
                                      icon: const Icon(Icons.receipt_long),
                                      label: const Text('View Payments'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        final route = Uri(
                                          path: '/owner/transactions',
                                          queryParameters: {
                                            'tenantId': tenant.id,
                                          },
                                        ).toString();
                                        context.go(route);
                                      },
                                      icon: const Icon(Icons.history),
                                      label: const Text('Transactions'),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Text(
                        "Vacant",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!room.isOccupied) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTenantScreen(
                        propertyId: property.id,
                        roomId: room.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text("Allocate"),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  Widget _statChip(ThemeData theme, String label, String value) {
    return Chip(
      label: Text("$label: $value", style: theme.textTheme.bodySmall),
      backgroundColor: Colors.white.withValues(alpha: 0.2),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic property) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Property?"),
        content: Text(
          "Are you sure you want to delete ${property.name}? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(deletePropertyUseCaseProvider).call(property.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Property deleted successfully"),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
