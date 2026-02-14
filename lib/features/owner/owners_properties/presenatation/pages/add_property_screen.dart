import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/providers/property_tenant_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/pages/property_detail_screen.dart';

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

  List<RoomInput> rooms = [];

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.property?.name ?? '');
    addressCtrl = TextEditingController(text: widget.property?.address ?? '');
    totalRoomsCtrl = TextEditingController(
      text: (widget.property?.totalRooms ?? 0).toString(),
    );

    if (widget.property != null) {
      rooms = widget.property!.rooms
          .map(
            (r) => RoomInput(id: r.id, roomNumber: r.roomNumber, name: r.name),
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
          ),
        );
      }
    } else if (count < rooms.length) {
      rooms = rooms.sublist(0, count);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.property != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit Property" : "Add Property")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 800 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Property Info
                      _buildCard(theme, "Property Information", [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: "Property Name",
                            hintText: "e.g., Sunshine Residency",
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? "Required" : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: addressCtrl,
                          decoration: InputDecoration(
                            labelText: "Address",
                            hintText: "e.g., 123 Main Street, City",
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines: 2,
                          validator: (value) =>
                              value?.isEmpty ?? true ? "Required" : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: totalRoomsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Total Rooms/Units",
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? "Required" : null,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Room Details
                      if (rooms.isNotEmpty)
                        _buildCard(theme, "Room/Unit Details", [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final room = rooms[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: room.roomNumber,
                                        decoration: InputDecoration(
                                          labelText: "Room #",
                                          filled: true,
                                          fillColor: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          room.roomNumber = value;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue: room.name,
                                        decoration: InputDecoration(
                                          labelText: "Room Name",
                                          filled: true,
                                          fillColor: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          room.name = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ]),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _save,
                              icon: Icon(isEditing ? Icons.save : Icons.add),
                              label: Text(isEditing ? "Update" : "Create"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
          );
        },
      ),
    );
  }

  Widget _buildCard(ThemeData theme, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
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

    final property = Property(
      id: widget.property?.id ?? const Uuid().v4(),
      name: nameCtrl.text,
      address: addressCtrl.text,
      totalRooms: int.parse(totalRoomsCtrl.text),
      rooms: rooms
          .map((r) => Room(id: r.id, roomNumber: r.roomNumber, name: r.name))
          .toList(),
    );

    try {
      if (widget.property != null) {
        // Update existing property
        await ref.read(firestoreServiceProvider).updateProperty(property);
      } else {
        // Add new property
        await ref.read(firestoreServiceProvider).addProperty(property);
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

  RoomInput({required this.id, required this.roomNumber, required this.name});
}
