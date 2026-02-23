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

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedCity.isEmpty ? 'Map' : 'Map - $selectedCity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city),
            onPressed: () => context.go('/tenant/city'),
            tooltip: 'Change city',
          ),
        ],
      ),
      body: selectedCity.isEmpty
          ? const Center(child: Text("No city selected"))
          : _MapBody(
              mapController: _mapController,
              selectedPropertyId: _selectedPropertyId,
              onMarkerTap: (p) {
                setState(() => _selectedPropertyId = p.id);
                _showPropertySheet(context, p);
              },
            ),
    );
  }

  void _showPropertySheet(BuildContext context, Property property) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              property.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(property.address),
            const SizedBox(height: 12),
            Text("Vacant Rooms: ${property.vacantRooms}"),
            const SizedBox(height: 8),
            Text("Lat: ${property.lat}, Lng: ${property.lng}"),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends ConsumerStatefulWidget {
  final MapController mapController;
  final String? selectedPropertyId;
  final void Function(Property) onMarkerTap;

  const _MapBody({
    required this.mapController,
    required this.selectedPropertyId,
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
            _scheduleAutoFit(
              cityCenter: cityCenter,
              properties: properties,
            );

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

            return FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                // only initial; auto-fit adjusts after load
                initialCenter: cityCenter,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'rentdone',
                ),

                /// ✅ Cluster layer + tap cluster to zoom
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    markers: markers,
                    maxClusterRadius: 45,
                    size: const Size(52, 52),

                    /// ✅ Tap cluster -> zoom/animate to its bounds
                    zoomToBoundsOnClick: true,

                    builder: (context, cluster) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10,
                              color: Colors.black.withValues(alpha: 0.35),
                              offset: const Offset(0, 6),
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

                if (properties.isEmpty)
                  const _MapOverlayMessage(
                    message:
                        'No published properties found for this city.\nCheck Firestore: city=Mumbai, isPublished=true, lat/lng are numbers.',
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
    final signature = properties
        .map((p) =>
            '${p.id}:${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}')
        .join('|');

    if (signature == _lastFitSignature) return;
    _lastFitSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (properties.isEmpty) {
        widget.mapController.move(cityCenter, 12);
        return;
      }

      if (properties.length == 1) {
        final p = properties.first;
        widget.mapController.move(LatLng(p.lat, p.lng), 15);
        return;
      }

      final points = properties.map((p) => LatLng(p.lat, p.lng)).toList();
      final bounds = LatLngBounds.fromPoints(points);

      widget.mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(80),
        ),
      );
    });
  }
}

class _MapOverlayMessage extends StatelessWidget {
  final String message;

  const _MapOverlayMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}