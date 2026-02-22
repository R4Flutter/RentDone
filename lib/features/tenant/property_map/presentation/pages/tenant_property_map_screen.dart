import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentdone/features/tenant/property_map/presentation/providers/tenant_map_providers.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class TenantPropertyMapScreen extends ConsumerWidget {
  final String? cityFromRoute;

  const TenantPropertyMapScreen({
    super.key,
    this.cityFromRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sync route query city into provider if needed
    final routeCity = (cityFromRoute ?? '').trim();
    if (routeCity.isNotEmpty) {
      final current = ref.read(selectedCityProvider);
      if (current.trim().toLowerCase() != routeCity.toLowerCase()) {
        ref.read(selectedCityProvider.notifier).state = routeCity;
      }
    }

    final selectedCity = ref.watch(selectedCityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedCity.trim().isEmpty ? 'Map' : 'Map - $selectedCity'),
        actions: [
          IconButton(
            onPressed: () => context.go('/tenant/city'),
            icon: const Icon(Icons.location_city),
            tooltip: 'Change city',
          ),
        ],
      ),
      body: selectedCity.trim().isEmpty
          ? _EmptyCityState(onPickCity: () => context.go('/tenant/city'))
          : _MapBody(city: selectedCity),
    );
  }
}

class _EmptyCityState extends StatelessWidget {
  final VoidCallback onPickCity;

  const _EmptyCityState({required this.onPickCity});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No city selected'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPickCity,
              child: const Text('Select City'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends ConsumerWidget {
  final String city;

  const _MapBody({required this.city});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centerAsync = ref.watch(cityCenterProvider);
    final propertiesAsync = ref.watch(tenantCityPropertiesProvider);

    return centerAsync.when(
      data: (center) {
        return propertiesAsync.when(
          data: (properties) {
            final markers = properties
                .map(
                  (p) => Marker(
                    point: LatLng(p.lat, p.lng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showPropertySheet(context, p),
                      child: const Icon(Icons.location_pin, size: 44),
                    ),
                  ),
                )
                .toList();

            return FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'rentdone',
                ),
                MarkerLayer(markers: markers),
                if (properties.isEmpty)
                  const _MapOverlayMessage(
                    message:
                        'No published properties found for this city.\nAsk developer to add properties with city/lat/lng and isPublished=true.',
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading properties: $e'),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Could not find city "$city".\nTry a different spelling.\n\nError: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  void _showPropertySheet(BuildContext context, Property property) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
              Row(
                children: [
                  const Icon(Icons.meeting_room, size: 18),
                  const SizedBox(width: 6),
                  Text('Rooms: ${property.totalRooms}'),
                  const SizedBox(width: 16),
                  const Icon(Icons.event_available, size: 18),
                  const SizedBox(width: 6),
                  Text('Vacant: ${property.vacantRooms}'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Later: navigate to property details/booking screen
                    // context.go('/tenant/property/${property.id}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Next step: open property details screen'),
                      ),
                    );
                  },
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        );
      },
    );
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