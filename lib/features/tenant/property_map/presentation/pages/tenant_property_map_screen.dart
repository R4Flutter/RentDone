import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentdone/features/tenant/property_map/presentation/providers/tenant_map_providers.dart';
import 'package:rentdone/features/tenant/property_map/presentation/widgets/tenant_property_marker.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class TenantPropertyMapScreen extends ConsumerStatefulWidget {
  final String? cityFromRoute;

  const TenantPropertyMapScreen({super.key, this.cityFromRoute});

  @override
  ConsumerState<TenantPropertyMapScreen> createState() =>
      _TenantPropertyMapScreenState();
}

class _TenantPropertyMapScreenState
    extends ConsumerState<TenantPropertyMapScreen> {
  final MapController _mapController = MapController();
  String? _selectedPropertyId;

  void _goToCityPicker() {
    context.go('/tenant/city');
  }

  @override
  Widget build(BuildContext context) {
    // Sync route city with provider
    final routeCity = (widget.cityFromRoute ?? '').trim();
    if (routeCity.isNotEmpty) {
      final current = ref.read(selectedCityProvider).trim();
      if (current.toLowerCase() != routeCity.toLowerCase()) {
        ref.read(selectedCityProvider.notifier).setCity(routeCity);
      }
    }

    final selectedCity = ref.watch(selectedCityProvider);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF0A1127), Color(0xFF132A57)]
                : const [Color(0xFFD9ECFF), Color(0xFFF6FAFF)],
          ),
        ),
        child: SafeArea(
          child: selectedCity.isEmpty
              ? _NoCitySelected(onTap: _goToCityPicker)
              : _MapBody(
                  mapController: _mapController,
                  city: selectedCity,
                  selectedPropertyId: _selectedPropertyId,
                  onChangeCity: _goToCityPicker,
                  onMarkerTap: (p) {
                    setState(() => _selectedPropertyId = p.id);
                    _showPropertySheet(context, p);
                  },
                ),
        ),
      ),
    );
  }

  void _showPropertySheet(BuildContext context, Property property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(property.address),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _InfoPill(
                        icon: Icons.meeting_room_outlined,
                        label: '${property.vacantRooms} vacant',
                      ),
                      const SizedBox(width: 8),
                      _InfoPill(
                        icon: Icons.location_on_outlined,
                        label: property.city,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapBody extends ConsumerStatefulWidget {
  final MapController mapController;
  final String city;
  final String? selectedPropertyId;
  final VoidCallback onChangeCity;
  final void Function(Property) onMarkerTap;

  const _MapBody({
    required this.mapController,
    required this.city,
    required this.selectedPropertyId,
    required this.onChangeCity,
    required this.onMarkerTap,
  });

  @override
  ConsumerState<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends ConsumerState<_MapBody> {
  /// Prevents repeatedly fitting camera on every rebuild.
  String _lastFitSignature = '';

  @override
  Widget build(BuildContext context) {
    final centerAsync = ref.watch(cityCenterProvider);
    final propertiesAsync = ref.watch(tenantCityPropertiesProvider);

    return centerAsync.when(
      data: (cityCenter) {
        return propertiesAsync.when(
          data: (properties) {
            // ✅ Auto-zoom to fit all properties (or center if none)
            _scheduleAutoFit(cityCenter: cityCenter, properties: properties);

            final markers = properties.map((p) {
              return Marker(
                point: LatLng(p.lat, p.lng),
                width: 80,
                height: 80,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onMarkerTap(p),
                  child: TenantPropertyMarker(
                    vacantRooms: p.vacantRooms,
                    selected: p.id == widget.selectedPropertyId,
                  ),
                ),
              );
            }).toList();

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: FlutterMap(
                      mapController: widget.mapController,
                      options: MapOptions(
                        // only initial; auto-fit adjusts after load
                        initialCenter: cityCenter,
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'rentdone',
                        ),

                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            markers: markers,
                            maxClusterRadius: 45,
                            size: const Size(54, 54),
                            zoomToBoundsOnClick: true,
                            builder: (context, cluster) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1E5BFF),
                                      Color(0xFF3F89FF),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 16,
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    cluster.length.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 22,
                  left: 24,
                  right: 24,
                  child: _GlassTopBar(
                    city: widget.city,
                    propertyCount: properties.length,
                    onChangeCity: widget.onChangeCity,
                  ),
                ),
                if (properties.isEmpty)
                  const Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: _MapOverlayMessage(
                      message:
                          'No published properties found in this city yet. Ask owners to publish properties with valid map coordinates.',
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Error loading properties: $e"),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("Error geocoding city: $e"),
        ),
      ),
    );
  }

  void _scheduleAutoFit({
    required LatLng cityCenter,
    required List<Property> properties,
  }) {
    final markerSignature = properties
        .map(
          (p) =>
              '${p.id}:${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}',
        )
        .join('|');
    final signature =
        '${widget.city.toLowerCase()}|${cityCenter.latitude.toStringAsFixed(4)},${cityCenter.longitude.toStringAsFixed(4)}|$markerSignature';

    if (signature == _lastFitSignature) return;
    _lastFitSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (properties.isEmpty) {
        widget.mapController.move(cityCenter, 13.5);
        return;
      }

      if (properties.length == 1) {
        final p = properties.first;
        widget.mapController.move(LatLng(p.lat, p.lng), 16);
        return;
      }

      final points = properties.map((p) => LatLng(p.lat, p.lng)).toList();
      final bounds = LatLngBounds.fromPoints(points);

      final latSpan = (bounds.north - bounds.south).abs();
      final lngSpan = (bounds.east - bounds.west).abs();
      final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

      // If properties are densely packed, force a tighter zoom to avoid stacked markers.
      if (maxSpan <= 0.008) {
        widget.mapController.move(bounds.center, 16.2);
        return;
      }
      if (maxSpan <= 0.02) {
        widget.mapController.move(bounds.center, 15.4);
        return;
      }
      if (maxSpan <= 0.05) {
        widget.mapController.move(bounds.center, 14.6);
        return;
      }

      widget.mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(64)),
      );
    });
  }
}

class _MapOverlayMessage extends StatelessWidget {
  final String message;

  const _MapOverlayMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoCitySelected extends StatelessWidget {
  final VoidCallback onTap;

  const _NoCitySelected({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_city_rounded, size: 44),
            const SizedBox(height: 14),
            const Text(
              'Select a city to open the property map',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.search),
              label: const Text('Choose City'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassTopBar extends StatelessWidget {
  final String city;
  final int propertyCount;
  final VoidCallback onChangeCity;

  const _GlassTopBar({
    required this.city,
    required this.propertyCount,
    required this.onChangeCity,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$propertyCount active properties',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onChangeCity,
                  icon: const Icon(Icons.swap_horiz, color: Colors.white),
                  label: const Text(
                    'Change',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}
