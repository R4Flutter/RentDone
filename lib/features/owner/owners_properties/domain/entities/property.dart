class Room {
  final String id;
  final String roomNumber;
  final String name;
  final bool isOccupied;
  final String? tenantId;

  const Room({
    required this.id,
    required this.roomNumber,
    required this.name,
    this.isOccupied = false,
    this.tenantId,
  });

  Room copyWith({
    String? id,
    String? roomNumber,
    String? name,
    bool? isOccupied,
    String? tenantId,
  }) {
    return Room(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      name: name ?? this.name,
      isOccupied: isOccupied ?? this.isOccupied,
      tenantId: tenantId ?? this.tenantId,
    );
  }
}

class Property{
  final String id;
  final String name;
  final String address;
  final int totalRooms;
  final List<Room> rooms;

  /// ✅ Added for tenant map
  final String city;
  final double lat;
  final double lng;

  /// ✅ Controls tenant visibility
  final bool isPublished;

  const Property({
    required this.id,
    required this.name,
    required this.address,
    required this.totalRooms,
    required this.rooms,
    required this.city,
    required this.lat,
    required this.lng,
    this.isPublished = false,
  });

  int get occupiedRooms => rooms.where((room) => room.isOccupied).length;
  int get vacantRooms => totalRooms - occupiedRooms;

  Property copyWith({
    String? id,
    String? name,
    String? address,
    int? totalRooms,
    List<Room>? rooms,
    String? city,
    double? lat,
    double? lng,
    bool? isPublished,
  }) {
    return Property(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      totalRooms: totalRooms ?? this.totalRooms,
      rooms: rooms ?? this.rooms,
      city: city ?? this.city,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isPublished: isPublished ?? this.isPublished,
    );
  }
}