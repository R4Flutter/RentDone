import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/pages/owner_add_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/providers/property_tenant_provider.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final propertyAsync = ref.watch(propertyProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Liquid gradient background
          Container(
            decoration: BoxDecoration(
              gradient: OwnerDashboardColors.managePropertiesBackgroundGradient(
                context,
              ),
            ),
          ),
          // Liquid ambient blobs
          _liquidBlob(top: -60, left: -60, size: 300, isDark: isDark),
          _liquidBlob(bottom: -80, right: -60, size: 240, isDark: isDark),
          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient:
                                OwnerDashboardColors.managePropertiesAccentGradient(
                                  context,
                                ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    OwnerDashboardColors.managePropertiesShadowColor(
                                      context,
                                    ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Property Details',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color:
                                    OwnerDashboardColors.managePropertiesHeaderPrimary(
                                      context,
                                    ),
                              ),
                            ),
                            Text(
                              'Rooms & tenant overview',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                color:
                                    OwnerDashboardColors.managePropertiesHeaderSecondary(
                                      context,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Body content
                Expanded(
                  child: propertyAsync.when(
                    data: (property) =>
                        _buildBody(context, ref, theme, property, isDark),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Property property,
    bool isDark,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property info glass card
          _buildPropertyInfoCard(context, theme, property, isDark),
          const SizedBox(height: 14),
          // Stat pills row
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _statChip(
                  context,
                  theme,
                  'Total',
                  property.totalRooms.toString(),
                ),
                const SizedBox(width: 8),
                _statChip(
                  context,
                  theme,
                  'Occupied',
                  property.occupiedRooms.toString(),
                ),
                const SizedBox(width: 8),
                _statChip(
                  context,
                  theme,
                  'Vacant',
                  property.vacantRooms.toString(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Room grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : 1,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isDesktop ? 1.1 : 2.4,
              ),
              itemCount: property.rooms.length,
              itemBuilder: (context, index) {
                final room = property.rooms[index];
                return _roomCard(context, ref, theme, property, room, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyInfoCard(
    BuildContext context,
    ThemeData theme,
    Property property,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.white.withAlpha(18), Colors.white.withAlpha(10)]
                  : [Colors.white.withAlpha(185), Colors.white.withAlpha(140)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withAlpha(46),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: OwnerDashboardColors.managePropertiesShadowColor(
                  context,
                ),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  gradient: OwnerDashboardColors.managePropertiesAccentGradient(
                    context,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color:
                            OwnerDashboardColors.managePropertiesHeaderPrimary(
                              context,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color:
                            OwnerDashboardColors.managePropertiesHeaderSecondary(
                              context,
                            ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: OwnerDashboardColors.managePropertiesPillBackground(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: OwnerDashboardColors.managePropertiesPillBorder(context),
          width: 1.0,
        ),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: OwnerDashboardColors.managePropertiesPillTextColor(context),
        ),
      ),
    );
  }

  Widget _roomCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Property property,
    Room room,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.white.withAlpha(18), Colors.white.withAlpha(10)]
                  : [Colors.white.withAlpha(185), Colors.white.withAlpha(140)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withAlpha(36),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: OwnerDashboardColors.managePropertiesShadowColor(
                  context,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room number badge + status badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          OwnerDashboardColors.managePropertiesAccentGradient(
                            context,
                          ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Room ${room.roomNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: room.isOccupied
                          ? AppTheme.liquidPrimaryEnd.withAlpha(26)
                          : AppColors.orange.withAlpha(26),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      room.isOccupied ? 'Occupied' : 'Vacant',
                      style: TextStyle(
                        color: room.isOccupied
                            ? AppTheme.liquidPrimaryEnd
                            : AppColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Tenant info
              Expanded(
                child: room.isOccupied && room.tenantId != null
                    ? FutureBuilder<Tenant?>(
                        future: ref
                            .read(getTenantByIdUseCaseProvider)
                            .call(room.tenantId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text(
                              'Loading...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    OwnerDashboardColors.managePropertiesHeaderSecondary(
                                      context,
                                    ),
                              ),
                            );
                          }
                          final tenant = snapshot.data;
                          if (tenant == null) {
                            return Text(
                              'Details unavailable',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    OwnerDashboardColors.managePropertiesHeaderSecondary(
                                      context,
                                    ),
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tenant.fullName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      OwnerDashboardColors.managePropertiesHeaderPrimary(
                                        context,
                                      ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tenant.phone,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      OwnerDashboardColors.managePropertiesHeaderSecondary(
                                        context,
                                      ),
                                ),
                              ),
                              if ((tenant.email ?? '').isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  tenant.email!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color:
                                        OwnerDashboardColors.managePropertiesHeaderSecondary(
                                          context,
                                        ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          );
                        },
                      )
                    : Text(
                        'Vacant room',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              OwnerDashboardColors.managePropertiesActionColor(
                                context,
                              ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () async {
                          if (!room.isOccupied || room.tenantId == null) {
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
                                  content: Text(
                                    'Tenant allocated successfully',
                                  ),
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
                                  backgroundColor: AppColors.orange,
                                ),
                              );
                            }
                            return;
                          }
                          if (!context.mounted) return;
                          _showTenantDetailsDialog(context, tenant);
                        },
                        child: Text(
                          room.isOccupied ? 'View' : 'Allocate',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: room.isOccupied
                              ? AppColors.red.withAlpha(200)
                              : Colors.grey.withAlpha(80),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
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
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.red,
                                        ),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Vacate'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    await ref
                                        .read(
                                          removeTenantNotifierProvider.notifier,
                                        )
                                        .removeTenant(
                                          tenantId,
                                          property.id,
                                          room.id,
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Room vacated'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                }
                              }
                            : null,
                        child: Text(
                          'Vacate',
                          style: TextStyle(
                            color: room.isOccupied
                                ? Colors.white
                                : Colors.grey.withAlpha(140),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  Widget _liquidBlob({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required bool isDark,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? AppTheme.liquidPrimaryStart.withAlpha(18)
              : AppTheme.liquidPrimaryStart.withAlpha(26),
        ),
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
