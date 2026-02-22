import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/pages/owner_add_property.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/providers/property_tenant_provider.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertyAsync = ref.watch(propertyProvider(widget.propertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Property Details')),
      body: propertyAsync.when(
        data: (property) => _buildBody(context, ref, theme, property),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Property property,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 1000 : double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(property.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(property.address, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _statChip(theme, 'Total', property.totalRooms.toString()),
                  _statChip(
                    theme,
                    'Occupied',
                    property.occupiedRooms.toString(),
                  ),
                  _statChip(theme, 'Vacant', property.vacantRooms.toString()),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 3 : 1,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: property.rooms.length,
                  itemBuilder: (context, index) {
                    final room = property.rooms[index];
                    return _roomCard(context, ref, theme, property, room);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(ThemeData theme, String label, String value) {
    return Chip(
      label: Text('$label: $value', style: theme.textTheme.bodySmall),
      backgroundColor: Colors.white.withAlpha(20),
    );
  }

  Widget _roomCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Property property,
    Room room,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Room ${room.roomNumber}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          room.isOccupied && room.tenantId != null
              ? FutureBuilder<Tenant?>(
                  future: ref
                      .read(getTenantByIdUseCaseProvider)
                      .call(room.tenantId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(
                        'Loading tenant...',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    final tenant = snapshot.data;
                    if (tenant == null) {
                      return Text(
                        'Occupied - details not available',
                        style: theme.textTheme.bodySmall,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tenant.fullName, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 4),
                        Text(tenant.phone, style: theme.textTheme.bodyMedium),
                        if ((tenant.email ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            tenant.email!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    );
                  },
                )
              : Text(
                  'Vacant',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.orange,
                  ),
                ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (!room.isOccupied || room.tenantId == null) {
                      // Navigate to Add Tenant Screen
                      final allocated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTenantScreen(
                            propertyId: property.id,
                            roomId: room.id,
                          ),
                        ),
                      );
                      if (context.mounted && allocated == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tenant allocated successfully'),
                          ),
                        );
                      }
                      return;
                    }

                    final tenant = await ref
                        .read(getTenantByIdUseCaseProvider)
                        .call(room.tenantId!);
                    if (tenant == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tenant not found'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      return;
                    }
                    if (!context.mounted) return;
                    _showTenantDetailsDialog(context, tenant);
                  },
                  child: Text(room.isOccupied ? 'View' : 'Allocate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: room.isOccupied
                      ? () async {
                          final tenantId = room.tenantId!;
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Vacate Room'),
                              content: Text(
                                'Are you sure you want to vacate Room ${room.roomNumber}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Vacate'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              await ref
                                  .read(removeTenantNotifierProvider.notifier)
                                  .removeTenant(tenantId, property.id, room.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Room vacated')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        }
                      : null,
                  child: const Text('Vacate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTenantDetailsDialog(BuildContext context, Tenant tenant) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tenant Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${tenant.fullName}'),
            Text('Phone: ${tenant.phone}'),
            Text(
              'Move-in: ${tenant.moveInDate.day}/${tenant.moveInDate.month}/${tenant.moveInDate.year}',
            ),
            Text('Rent: Rs ${tenant.rentAmount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
