import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/pages/owner_add_property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/providers/property_tenant_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
                childAspectRatio: isDesktop ? 1.1 : 1.55,
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
                  ? [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.72),
                      Colors.white.withValues(alpha: 0.55),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.18),
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
                  ? [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.72),
                      Colors.white.withValues(alpha: 0.55),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.14),
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
                          ? AppTheme.liquidPrimaryEnd.withValues(alpha: 0.1)
                          : AppColors.orange.withValues(alpha: 0.1),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                              _showLiquidSnackBar(
                                context,
                                message: 'Tenant allocated successfully',
                                status: _LiquidSnackBarStatus.success,
                              );
                            }
                            return;
                          }
                          final tenant = await ref
                              .read(getTenantByIdUseCaseProvider)
                              .call(room.tenantId!);
                          if (tenant == null) {
                            if (context.mounted) {
                              _showLiquidSnackBar(
                                context,
                                message: 'Tenant not found for this room',
                                status: _LiquidSnackBarStatus.warning,
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
                              ? AppColors.red.withValues(alpha: 0.78)
                              : Colors.grey.withValues(alpha: 0.31),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: room.isOccupied
                            ? () async {
                                final tenantId = room.tenantId!;
                                
                                // Fetch tenant to check for documents
                                final tenant = await ref
                                    .read(getTenantByIdUseCaseProvider)
                                    .call(tenantId);
                                
                                final hasDocs = tenant != null && (
                                  (tenant.photoUrl ?? '').isNotEmpty ||
                                  (tenant.idDocumentUrl ?? '').isNotEmpty ||
                                  tenant.documentUrls.isNotEmpty
                                );

                                if (!context.mounted) return;

                                final result = await _showVacateRoomDialog(
                                  context,
                                  roomNumber: room.roomNumber,
                                  hasDocuments: hasDocs,
                                );
                                
                                if (result?.confirmed == true) {
                                  try {
                                    if (result?.downloadDocs == true && tenant != null) {
                                      await _downloadTenantDocuments(tenant);
                                    }

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
                                      _showLiquidSnackBar(
                                        context,
                                        message: 'Room vacated successfully',
                                        status: _LiquidSnackBarStatus.success,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      _showLiquidSnackBar(
                                        context,
                                        message:
                                            'Unable to vacate room. Please try again.',
                                        status: _LiquidSnackBarStatus.error,
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
                                : Colors.grey.withValues(alpha: 0.55),
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

  void _showLiquidSnackBar(
    BuildContext context, {
    required String message,
    required _LiquidSnackBarStatus status,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        duration: Duration(
          milliseconds: status == _LiquidSnackBarStatus.error ? 3400 : 2600,
        ),
        content: _LiquidStatusSnackBar(message: message, status: status),
      ),
    );
  }

  Future<void> _downloadTenantDocuments(Tenant tenant) async {
    final urls = <String>[];
    if ((tenant.photoUrl ?? '').isNotEmpty) urls.add(tenant.photoUrl!);
    if ((tenant.idDocumentUrl ?? '').isNotEmpty) urls.add(tenant.idDocumentUrl!);
    urls.addAll(tenant.documentUrls.where((u) => u.isNotEmpty));

    if (urls.isEmpty) return;

    for (final url in urls) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Add a small delay between launches to avoid browser issues
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<({bool confirmed, bool downloadDocs})?> _showVacateRoomDialog(
    BuildContext context, {
    required String roomNumber,
    bool hasDocuments = false,
  }) {
    final isDark = OwnerDashboardColors.isDark(context);
    return showGeneralDialog<({bool confirmed, bool downloadDocs})>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.black.withValues(alpha: isDark ? 0.48 : 0.24),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _LiquidVacateDialog(
          roomNumber: roomNumber,
          hasDocuments: hasDocuments,
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(scale),
            child: child,
          ),
        );
      },
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
              ? AppTheme.liquidPrimaryStart.withValues(alpha: 0.07)
              : AppTheme.liquidPrimaryStart.withValues(alpha: 0.1),
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

enum _LiquidSnackBarStatus { success, warning, error }

class _LiquidStatusSnackBar extends StatelessWidget {
  const _LiquidStatusSnackBar({required this.message, required this.status});

  final String message;
  final _LiquidSnackBarStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final isError = status == _LiquidSnackBarStatus.error;
    final isWarning = status == _LiquidSnackBarStatus.warning;
    final accentA = isError
        ? const Color(0xFFFF5A78)
        : isWarning
        ? const Color(0xFFFFC857)
        : const Color(0xFF1ED6A0);
    final accentB = isError
        ? const Color(0xFFFF2D55)
        : isWarning
        ? const Color(0xFFFF9F1A)
        : const Color(0xFF0AAE84);
    final icon = isError
        ? Icons.error_outline_rounded
        : isWarning
        ? Icons.warning_amber_rounded
        : Icons.check_rounded;
    final title = isError
        ? 'Action failed'
        : isWarning
        ? 'Heads up'
        : 'Success';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF102040).withValues(alpha: isDark ? 0.88 : 0.80),
                const Color(0xFF0A1329).withValues(alpha: isDark ? 0.82 : 0.74),
              ],
            ),
            border: Border.all(
              color: AppColors.white.withValues(alpha: isDark ? 0.20 : 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.30 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accentA, accentB],
                  ),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(icon, size: 18, color: AppColors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
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
}

class _LiquidVacateDialog extends StatefulWidget {
  const _LiquidVacateDialog({required this.roomNumber, this.hasDocuments = false});

  final String roomNumber;
  final bool hasDocuments;

  @override
  State<_LiquidVacateDialog> createState() => _LiquidVacateDialogState();
}

class _LiquidVacateDialogState extends State<_LiquidVacateDialog> {
  bool _downloadDocs = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final brandSoft = OwnerDashboardColors.brandPrimarySoft(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final surfaceStart =
        Color.lerp(OwnerDashboardColors.cardBackground(context), brand, 0.14) ??
        OwnerDashboardColors.cardBackground(context);
    final surfaceEnd =
        Color.lerp(
          OwnerDashboardColors.elevatedBackground(context),
          brand,
          0.20,
        ) ??
        OwnerDashboardColors.elevatedBackground(context);
    final destructiveStart = AppTheme.errorRed;
    final destructiveEnd =
        Color.lerp(AppTheme.errorRed, AppColors.black, 0.20) ??
        AppTheme.errorRed;
    final shadowColor = OwnerDashboardColors.managePropertiesShadowColor(
      context,
    ).withValues(alpha: isDark ? 0.38 : 0.16);

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: AppColors.black.withValues(alpha: isDark ? 0.20 : 0.08),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            surfaceStart.withValues(
                              alpha: isDark ? 0.94 : 0.88,
                            ),
                            surfaceEnd.withValues(alpha: isDark ? 0.90 : 0.82),
                          ],
                        ),
                        border: Border.all(
                          color: brand.withValues(alpha: isDark ? 0.28 : 0.22),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 34,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -44,
                            left: -40,
                            child: _LiquidOrb(
                              size: 132,
                              color: brand.withValues(
                                alpha: isDark ? 0.28 : 0.20,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -54,
                            right: -32,
                            child: _LiquidOrb(
                              size: 142,
                              color: brandSoft.withValues(
                                alpha: isDark ? 0.30 : 0.24,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 68,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(30),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.white.withValues(
                                      alpha: isDark ? 0.14 : 0.20,
                                    ),
                                    AppColors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        destructiveStart,
                                        destructiveEnd,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: AppColors.white.withValues(
                                        alpha: isDark ? 0.28 : 0.34,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: destructiveEnd.withValues(
                                          alpha: isDark ? 0.46 : 0.36,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.white,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Vacate Room',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Are you sure you want to vacate Room ${widget.roomNumber}?',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textSecondary.withValues(
                                      alpha: 0.98,
                                    ),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: brand.withValues(
                                      alpha: isDark ? 0.14 : 0.10,
                                    ),
                                    border: Border.all(
                                      color: brand.withValues(
                                        alpha: isDark ? 0.34 : 0.24,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'This action cannot be undone',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                if (widget.hasDocuments) ...[
                                  const SizedBox(height: 16),
                                  Material(
                                    color: Colors.transparent,
                                    child: CheckboxListTile(
                                      value: _downloadDocs,
                                      onChanged: (v) => setState(() => _downloadDocs = v ?? false),
                                      title: Text(
                                        'Download tenant documents before deleting',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Documents will be permanently removed from server after vacating.',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: textSecondary,
                                        ),
                                      ),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      activeColor: brand,
                                      checkColor: Colors.white,
                                      dense: true,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _LiquidActionButton(
                                        label: 'Cancel',
                                        isPrimary: false,
                                        onTap: () =>
                                            Navigator.of(context).pop((confirmed: false, downloadDocs: false)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _LiquidActionButton(
                                        label: 'Vacate',
                                        isPrimary: true,
                                        onTap: () =>
                                            Navigator.of(context).pop((confirmed: true, downloadDocs: _downloadDocs)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiquidOrb extends StatelessWidget {
  const _LiquidOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: color.a * 0.45),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidActionButton extends StatefulWidget {
  const _LiquidActionButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  State<_LiquidActionButton> createState() => _LiquidActionButtonState();
}

class _LiquidActionButtonState extends State<_LiquidActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final elevated = OwnerDashboardColors.elevatedBackground(context);
    final textColor = widget.isPrimary
        ? AppColors.white
        : OwnerDashboardColors.textPrimary(context);
    final destructiveStart = AppTheme.errorRed;
    final destructiveEnd =
        Color.lerp(AppTheme.errorRed, AppColors.black, 0.20) ??
        AppTheme.errorRed;
    final cancelBg = elevated.withValues(alpha: isDark ? 0.58 : 0.78);
    final cancelBg2 = elevated.withValues(alpha: isDark ? 0.46 : 0.64);
    final cancelBorder = brand.withValues(alpha: isDark ? 0.26 : 0.20);

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: _pressed ? 0.97 : 1,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _pressed ? 0.92 : 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: widget.isPrimary
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [destructiveStart, destructiveEnd],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [cancelBg, cancelBg2],
                        ),
                  border: Border.all(
                    color: widget.isPrimary
                        ? AppColors.white.withValues(alpha: 0.18)
                        : cancelBorder,
                    width: 1.0,
                  ),
                  boxShadow: widget.isPrimary
                      ? [
                          BoxShadow(
                            color: destructiveEnd.withValues(alpha: 0.34),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
