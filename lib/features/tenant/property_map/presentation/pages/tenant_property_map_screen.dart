import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentdone/features/tenant/property_map/presentation/providers/tenant_map_providers.dart';
import 'package:rentdone/features/tenant/property_map/presentation/widgets/owner_info_card.dart';
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
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/tenant/city');
  }

  void _handleSystemBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/tenant/dashboard');
  }

  @override
  Widget build(BuildContext context) {
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
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
      ),
    );
  }

  void _showPropertySheet(BuildContext context, Property property) {
    final ownerId = property.ownerId.trim();
    final fallbackLocation =
        '${property.address.trim()}, ${property.city.trim()}'.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final ownerAsync = ownerId.isEmpty
              ? const AsyncValue<OwnerMapCardData?>.data(null)
              : ref.watch(ownerMapCardProvider(ownerId));

          return ClipRRect(
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ownerAsync.when(
                            data: (owner) {
                              return OwnerInfoCard(
                                ownerName: owner?.name.trim().isNotEmpty == true
                                    ? owner!.name
                                    : 'Property Owner',
                                ownerPhone: owner?.phoneNumber ?? '',
                                ownerLocation:
                                    owner?.locationAddress.trim().isNotEmpty ==
                                        true
                                    ? owner!.locationAddress
                                    : fallbackLocation,
                              );
                            },
                            loading: () => const _OwnerCardLoading(),
                            error: (error, _) => _OwnerCardError(
                              message: 'Could not load owner details yet.',
                              onRetry: () =>
                                  ref.invalidate(ownerMapCardProvider(ownerId)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            property.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(property.address),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoPill(
                                icon: Icons.meeting_room_outlined,
                                label: '${property.vacantRooms} vacant',
                              ),
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
            ),
          );
        },
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
  String _lastFitSignature = '';
  String _searchQuery = '';
  bool _onlyVacant = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centerAsync = ref.watch(cityCenterProvider);
    final propertiesAsync = ref.watch(tenantCityPropertiesProvider);

    return centerAsync.when(
      data: (cityCenter) {
        return propertiesAsync.when(
          data: (properties) {
            final filteredProperties = properties.where((property) {
              final matchesVacancy = !_onlyVacant || property.vacantRooms > 0;
              if (!matchesVacancy) return false;

              final query = _searchQuery.trim().toLowerCase();
              if (query.isEmpty) return true;

              final haystack = [
                property.name,
                property.address,
                property.city,
              ].join(' ').toLowerCase();
              return haystack.contains(query);
            }).toList();

            _scheduleAutoFit(
              cityCenter: cityCenter,
              properties: filteredProperties,
            );

            final markers = filteredProperties.map((p) {
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
                  top: 16,
                  left: 18,
                  right: 18,
                  child: _MapSearchHeader(
                    city: widget.city,
                    totalPropertyCount: properties.length,
                    visiblePropertyCount: filteredProperties.length,
                    searchQuery: _searchQuery,
                    searchController: _searchController,
                    onlyVacant: _onlyVacant,
                    onChangeCity: widget.onChangeCity,
                    onSearchChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    onToggleVacant: () {
                      setState(() => _onlyVacant = !_onlyVacant);
                    },
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 26,
                  child: _MapControlStack(
                    onZoomIn: () => _zoomBy(0.8),
                    onZoomOut: () => _zoomBy(-0.8),
                    onRecenter: () => _fitCameraNow(
                      cityCenter: cityCenter,
                      properties: filteredProperties,
                    ),
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
                if (properties.isNotEmpty && filteredProperties.isEmpty)
                  const Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: _MapOverlayMessage(
                      message:
                          'No properties match the current search or filters. Try clearing search or turning off Vacant only.',
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

      _fitCameraNow(cityCenter: cityCenter, properties: properties);
    });
  }

  void _fitCameraNow({
    required LatLng cityCenter,
    required List<Property> properties,
  }) {
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
  }

  void _zoomBy(double delta) {
    final camera = widget.mapController.camera;
    final nextZoom = (camera.zoom + delta).clamp(3.0, 18.5);
    widget.mapController.move(camera.center, nextZoom);
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

class _MapSearchHeader extends StatelessWidget {
  final String city;
  final int totalPropertyCount;
  final int visiblePropertyCount;
  final String searchQuery;
  final TextEditingController searchController;
  final bool onlyVacant;
  final VoidCallback onChangeCity;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleVacant;
  final VoidCallback onClearSearch;

  const _MapSearchHeader({
    required this.city,
    required this.totalPropertyCount,
    required this.visiblePropertyCount,
    required this.searchQuery,
    required this.searchController,
    required this.onlyVacant,
    required this.onChangeCity,
    required this.onSearchChanged,
    required this.onToggleVacant,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withValues(alpha: 0.42),
                Colors.black.withValues(alpha: 0.24),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.travel_explore_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onChangeCity,
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      label: const Text(
                        'Area',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                Text(
                  '$visiblePropertyCount shown • $totalPropertyCount total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by property, address, or locality',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                    ),
                    suffixIcon: searchQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClearSearch,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.18),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.26),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.8,
                        ),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Vacant Only'),
                      selected: onlyVacant,
                      onSelected: (_) => onToggleVacant(),
                      selectedColor: theme.colorScheme.secondary.withValues(
                        alpha: 0.32,
                      ),
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                    ),
                    _StatusTag(
                      label: searchQuery.trim().isEmpty
                          ? 'Live city feed'
                          : 'Search active',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControlStack extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  const _MapControlStack({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapControlButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom in',
                onTap: onZoomIn,
              ),
              _MapControlButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom out',
                onTap: onZoomOut,
              ),
              _MapControlButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Recenter results',
                onTap: onRecenter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;

  const _StatusTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
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

class _OwnerCardLoading extends StatelessWidget {
  const _OwnerCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('Loading owner details...')),
        ],
      ),
    );
  }
}

class _OwnerCardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OwnerCardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.45),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
