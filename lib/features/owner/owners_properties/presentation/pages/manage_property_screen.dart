import 'dart:ui';

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
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    OwnerDashboardColors.managePropertiesBackgroundGradient(
                      context,
                    ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            left: -50,
            child: _liquidBlob(
              220,
              OwnerDashboardColors.ownerTopBlobColor(context),
            ),
          ),
          Positioned(
            bottom: -110,
            right: -40,
            child: _liquidBlob(
              260,
              OwnerDashboardColors.ownerBottomBlobColor(context),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1200 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Manage Properties",
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                OwnerDashboardColors.managePropertiesHeaderPrimary(
                                                  context,
                                                ),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Track units, occupancy and tenants",
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 14,
                                        color:
                                            OwnerDashboardColors.managePropertiesHeaderSecondary(
                                              context,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient:
                                      OwnerDashboardColors.managePropertiesAccentGradient(
                                        context,
                                      ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          OwnerDashboardColors.managePropertiesShadowColor(
                                            context,
                                          ),
                                      blurRadius: 25,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Material(
                                    color: AppColors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AddPropertyScreen(),
                                          ),
                                        );
                                      },
                                      child: const Icon(
                                        Icons.add,
                                        size: 22,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: propertiesAsync.when(
                              data: (properties) {
                                if (properties.isEmpty) {
                                  return _emptyState(context, theme);
                                }

                                final totalRooms = properties.fold<int>(
                                  0,
                                  (sum, p) => sum + p.totalRooms,
                                );
                                final occupiedRooms = properties.fold<int>(
                                  0,
                                  (sum, p) => sum + p.occupiedRooms,
                                );
                                final vacantRooms = properties.fold<int>(
                                  0,
                                  (sum, p) => sum + p.vacantRooms,
                                );

                                return ListView(
                                  children: [
                                    _summaryStrip(
                                      context,
                                      theme,
                                      propertiesCount: properties.length,
                                      totalRooms: totalRooms,
                                      occupiedRooms: occupiedRooms,
                                      vacantRooms: vacantRooms,
                                    ),
                                    const SizedBox(height: 24),
                                    ...properties.map((property) {
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PropertyDetailScreen(
                                                    propertyId: property.id,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: _propertyCard(
                                          context,
                                          ref,
                                          theme,
                                          property,
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (err, stk) => Center(
                                child: Text(
                                  "Error: $err",
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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

  Widget _emptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white.withValues(alpha: 0.14),
                  OwnerDashboardColors.brandPrimary(
                    context,
                  ).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: OwnerDashboardColors.border(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.home_work_outlined,
                  size: 58,
                  color: OwnerDashboardColors.iconPrimary(context),
                ),
                const SizedBox(height: 14),
                Text("No properties yet", style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  "Create your first property to get started",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: OwnerDashboardColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: OwnerDashboardColors.brandPrimary(context),
                    foregroundColor: AppColors.white,
                  ),
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
          ),
        ),
      ),
    );
  }

  Widget _summaryStrip(
    BuildContext context,
    ThemeData theme, {
    required int propertiesCount,
    required int totalRooms,
    required int occupiedRooms,
    required int vacantRooms,
  }) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _summaryChip(
            context,
            theme,
            "Properties",
            propertiesCount.toString(),
          ),
          const SizedBox(width: 10),
          _summaryChip(context, theme, "Rooms", totalRooms.toString()),
          const SizedBox(width: 10),
          _summaryChip(context, theme, "Occupied", occupiedRooms.toString()),
          const SizedBox(width: 10),
          _summaryChip(context, theme, "Vacant", vacantRooms.toString()),
        ],
      ),
    );
  }

  Widget _summaryChip(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.55)),
      ),
      child: Text(
        "$label: $value",
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: OwnerDashboardColors.managePropertiesPillTextColor(context),
        ),
      ),
    );
  }

  Widget _propertyCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    dynamic property,
  ) {
    final isDark = OwnerDashboardColors.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.white.withValues(alpha: isDark ? 0.14 : 0.88),
                OwnerDashboardColors.managePropertiesCardTint(
                  context,
                ).withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: OwnerDashboardColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: OwnerDashboardColors.managePropertiesShadowColor(
                  context,
                ),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
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
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          property.address,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: OwnerDashboardColors.textSecondary(context),
                          ),
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
                              builder: (_) =>
                                  AddPropertyScreen(propertyId: property.id),
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
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statChip(
                    context,
                    theme,
                    "Total Rooms",
                    property.totalRooms.toString(),
                  ),
                  _statChip(
                    context,
                    theme,
                    "Occupied",
                    property.occupiedRooms.toString(),
                  ),
                  _statChip(
                    context,
                    theme,
                    "Vacant",
                    property.vacantRooms.toString(),
                  ),
                ],
              ),
              if (property.rooms.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  "Rooms",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: OwnerDashboardColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                ..._buildRoomsList(context, ref, theme, property),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRoomsList(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    dynamic property,
  ) {
    final isDark = OwnerDashboardColors.isDark(context);
    return property.rooms.map<Widget>((room) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(
                    alpha: isDark ? 0.12 : 0.55,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: OwnerDashboardColors.border(
                      context,
                    ).withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Room ${room.roomNumber}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                                  color: AppColors.grey,
                                  fontSize: 11,
                                ),
                              );
                            }

                            final tenant = snapshot.data;
                            if (tenant == null) {
                              return Text(
                                "Occupied",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.red,
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
                                    color: AppColors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final buttonWidth = (constraints.maxWidth)
                                          .clamp(104.0, 142.0)
                                          .toDouble();

                                      return SizedBox(
                                        width: buttonWidth,
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                OwnerDashboardColors.managePropertiesActionColor(
                                                  context,
                                                ),
                                            foregroundColor: AppColors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 9,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                          ),
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
                                          icon: const Icon(
                                            Icons.receipt_long,
                                            size: 15,
                                          ),
                                          label: Text(
                                            'Payments',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.white,
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if ((tenant.email ?? '').isNotEmpty)
                                  const SizedBox(height: 6),
                                if ((tenant.email ?? '').isNotEmpty)
                                  Text(
                                    tenant.email!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: AppColors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                          color: AppColors.orange,
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
                style: FilledButton.styleFrom(
                  backgroundColor:
                      OwnerDashboardColors.managePropertiesActionColor(context),
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
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

  Widget _statChip(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OwnerDashboardColors.managePropertiesPillBackground(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: OwnerDashboardColors.managePropertiesPillBorder(context),
        ),
      ),
      child: Text(
        "$label: $value",
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: OwnerDashboardColors.managePropertiesPillTextColor(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic property) {
    final screenContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Property?"),
        content: Text(
          "Are you sure you want to delete ${property.name}? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(deletePropertyUseCaseProvider).call(property.id);
                if (screenContext.mounted) {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    const SnackBar(
                      content: Text("Property deleted successfully"),
                    ),
                  );
                }
              } catch (e) {
                if (screenContext.mounted) {
                  ScaffoldMessenger.of(
                    screenContext,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
