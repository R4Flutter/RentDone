import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/providers/property_tenant_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/pages/property_detail_screen.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  final Property? property;

  const AddPropertyScreen({super.key, this.property});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController totalRoomsCtrl;
  late TextEditingController cityCtrl;
  late TextEditingController latCtrl;
  late TextEditingController lngCtrl;

  bool isPublished = false;
  bool _isFetchingLocation = false;

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      } 

      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      
      latCtrl.text = position.latitude.toStringAsFixed(6);
      lngCtrl.text = position.longitude.toStringAsFixed(6);

      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          if (place.locality != null && place.locality!.isNotEmpty) {
            cityCtrl.text = place.locality!;
          } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
             cityCtrl.text = place.subAdministrativeArea!;
          }
        }
      } catch (e) {
        // Geocoding failed, but we got coordinates
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  List<RoomInput> rooms = [];

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.property?.name ?? '');
    addressCtrl = TextEditingController(text: widget.property?.address ?? '');
    totalRoomsCtrl = TextEditingController(
      text: (widget.property?.totalRooms ?? 0).toString(),
    );
    cityCtrl = TextEditingController(text: widget.property?.city ?? '');
    latCtrl = TextEditingController(
      text: (widget.property?.lat ?? 0.0).toString(),
    );
    lngCtrl = TextEditingController(
      text: (widget.property?.lng ?? 0.0).toString(),
    );
    isPublished = widget.property?.isPublished ?? false;

    if (widget.property != null) {
      rooms = widget.property!.rooms
          .map(
            (r) => RoomInput(
              id: r.id,
              roomNumber: r.roomNumber,
              name: r.name,
              isOccupied: r.isOccupied,
              tenantId: r.tenantId,
            ),
          )
          .toList();
    }

    totalRoomsCtrl.addListener(_updateRoomCount);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addressCtrl.dispose();
    totalRoomsCtrl.dispose();
    cityCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    super.dispose();
  }

  void _updateRoomCount() {
    final count = int.tryParse(totalRoomsCtrl.text) ?? 0;
    if (count > rooms.length) {
      for (int i = rooms.length; i < count; i++) {
        rooms.add(
          RoomInput(
            id: const Uuid().v4(),
            roomNumber: '${i + 1}',
            name: 'Room ${i + 1}',
            isOccupied: false,
            tenantId: null,
          ),
        );
      }
    } else if (count < rooms.length) {
      final removedRooms = rooms.sublist(count);
      final removingOccupiedRoom = removedRooms.any((room) => room.isOccupied);
      if (removingOccupiedRoom) {
        totalRoomsCtrl.removeListener(_updateRoomCount);
        totalRoomsCtrl.text = rooms.length.toString();
        totalRoomsCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: totalRoomsCtrl.text.length),
        );
        totalRoomsCtrl.addListener(_updateRoomCount);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot remove occupied rooms. Remove tenants first.',
            ),
          ),
        );
        return;
      }
      rooms = rooms.sublist(0, count);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.property != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: OwnerDashboardColors.managePropertiesBackgroundGradient(
                context,
              ),
            ),
          ),
          // Liquid blobs
          _liquidBlob(
            left: -60,
            top: -80,
            size: 300,
            color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.12),
          ),
          _liquidBlob(
            right: -80,
            bottom: 100,
            size: 240,
            color: AppTheme.liquidPrimaryEnd.withValues(alpha: 0.09),
          ),
          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Column(
                  children: [
                    // Custom header
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32 : 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.liquidPrimaryStart,
                                    AppTheme.liquidPrimaryEnd,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.liquidShadow,
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Property' : 'Add Property',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color:
                                      OwnerDashboardColors.managePropertiesHeaderPrimary(
                                        context,
                                      ),
                                ),
                              ),
                              Text(
                                isEditing
                                    ? 'Update property details'
                                    : 'Create a new property',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      OwnerDashboardColors.managePropertiesHeaderSecondary(
                                        context,
                                      ),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Scrollable form
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 800 : double.infinity,
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: isDesktop ? 32 : 20,
                              right: isDesktop ? 32 : 20,
                              top: 8,
                              bottom: 32,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildGlassCard(
                                    context,
                                    theme,
                                    'Property Information',
                                    [
                                      _glassField(
                                        controller: nameCtrl,
                                        label: 'Property Name',
                                        hint: 'e.g., Sunshine Residency',
                                        validator: (v) => v?.isEmpty ?? true
                                            ? 'Required'
                                            : null,
                                      ),
                                      const SizedBox(height: 16),
                                      _glassField(
                                        controller: addressCtrl,
                                        label: 'Address',
                                        hint: 'e.g., 123 Main Street, City',
                                        maxLines: 2,
                                        validator: (v) => v?.isEmpty ?? true
                                            ? 'Required'
                                            : null,
                                      ),
                                      const SizedBox(height: 16),
                                      _glassField(
                                        controller: totalRoomsCtrl,
                                        label: 'Total Rooms/Units',
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v?.isEmpty ?? true
                                            ? 'Required'
                                            : null,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildGlassCard(
                                    context,
                                    theme,
                                    'Map Location (Tenant View)',
                                    [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                                          icon: _isFetchingLocation
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Icon(Icons.my_location_rounded),
                                          label: const Text('Use My Location'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _glassField(
                                        controller: cityCtrl,
                                        label: 'City',
                                        hint: 'e.g., Mumbai',
                                        validator: (v) =>
                                            v?.trim().isEmpty ?? true
                                                ? 'Required'
                                                : null,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _glassField(
                                              controller: latCtrl,
                                              label: 'Latitude',
                                              hint: 'e.g., 19.115',
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                    signed: true,
                                                  ),
                                              validator: (v) {
                                                final t = v?.trim() ?? '';
                                                if (t.isEmpty) return 'Required';
                                                final d = double.tryParse(t);
                                                if (d == null) {
                                                  return 'Invalid latitude';
                                                }
                                                if (d < -90 || d > 90) {
                                                  return 'Latitude must be -90 to 90';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _glassField(
                                              controller: lngCtrl,
                                              label: 'Longitude',
                                              hint: 'e.g., 72.867',
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                    signed: true,
                                                  ),
                                              validator: (v) {
                                                final t = v?.trim() ?? '';
                                                if (t.isEmpty) return 'Required';
                                                final d = double.tryParse(t);
                                                if (d == null) {
                                                  return 'Invalid longitude';
                                                }
                                                if (d < -180 || d > 180) {
                                                  return 'Longitude must be -180 to 180';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SwitchListTile.adaptive(
                                        value: isPublished,
                                        onChanged: (value) =>
                                            setState(() => isPublished = value),
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text(
                                          'Publish (visible to tenants)',
                                        ),
                                        subtitle: const Text(
                                          "If off, tenants won't see this property on the map.",
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  if (rooms.isNotEmpty)
                                    _buildGlassCard(
                                      context,
                                      theme,
                                      'Room / Unit Details',
                                      [
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: rooms.length,
                                          itemBuilder: (context, index) {
                                            final room = rooms[index];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: _glassField(
                                                      initialValue:
                                                          room.roomNumber,
                                                      label: 'Room #',
                                                      onChanged: (v) {
                                                        room.roomNumber = v;
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    flex: 2,
                                                    child: _glassField(
                                                      initialValue: room.name,
                                                      label: 'Room Name',
                                                      onChanged: (v) {
                                                        room.name = v;
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 28),
                                  // Equal-size action buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.liquidPrimaryEnd,
                                            side: const BorderSide(
                                              color: AppTheme.liquidPrimaryEnd,
                                              width: 1.5,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            minimumSize: const Size(0, 50),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _save,
                                          icon: Icon(
                                            isEditing
                                                ? Icons.save_rounded
                                                : Icons.add_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            isEditing ? 'Update' : 'Create',
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.liquidPrimaryEnd,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            minimumSize: const Size(0, 50),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
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
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _liquidBlob({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required Color color,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context,
    ThemeData theme,
    String title,
    List<Widget> children,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.72),
                AppTheme.liquidPrimaryStart.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.liquidShadow,
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.liquidPrimaryStart,
                          AppTheme.liquidPrimaryEnd,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: OwnerDashboardColors.managePropertiesHeaderPrimary(
                        context,
                      ),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppTheme.liquidPrimaryStart.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppTheme.liquidPrimaryEnd,
            width: 1.8,
          ),
        ),
      ),
      validator: validator,
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (rooms.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Add at least one room")));
      return;
    }

    final lat = double.parse(latCtrl.text.trim());
    final lng = double.parse(lngCtrl.text.trim());

    final property = Property(
      id: widget.property?.id ?? const Uuid().v4(),
      name: nameCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      totalRooms: int.parse(totalRoomsCtrl.text.trim()),
      rooms: rooms
          .map(
            (r) => Room(
              id: r.id,
              roomNumber: r.roomNumber,
              name: r.name,
              isOccupied: r.isOccupied,
              tenantId: r.tenantId,
            ),
          )
          .toList(),
      city: cityCtrl.text.trim(),
      lat: lat,
      lng: lng,
      isPublished: isPublished,
    );

    try {
      if (widget.property != null) {
        await ref.read(updatePropertyUseCaseProvider)(property);
      } else {
        await ref.read(addPropertyUseCaseProvider)(property);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.property != null
                  ? "Property updated successfully!"
                  : "Property created successfully!",
            ),
          ),
        );
        // Navigate to property detail after creation/update
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(propertyId: property.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}

class RoomInput {
  String id;
  String roomNumber;
  String name;
  bool isOccupied;
  String? tenantId;

  RoomInput({
    required this.id,
    required this.roomNumber,
    required this.name,
    this.isOccupied = false,
    this.tenantId,
  });
}
