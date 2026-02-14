class Room {
  final String id;
  final String roomNumber;
  final String name;
  final bool isOccupied;
  final String? tenantId; // Links to tenant
  
  Room({
    required this.id,
    required this.roomNumber,
    required this.name,
    this.isOccupied = false,
    this.tenantId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomNumber': roomNumber,
      'name': name,
      'isOccupied': isOccupied,
      'tenantId': tenantId,
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] ?? '',
      roomNumber: map['roomNumber'] ?? '',
      name: map['name'] ?? '',
      isOccupied: map['isOccupied'] ?? false,
      tenantId: map['tenantId'],
    );
  }

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

class Property {
  final String id;
  final String name;
  final String address;
  final int totalRooms;
  final List<Room> rooms;

  Property({
    required this.id,
    required this.name,
    required this.address,
    required this.totalRooms,
    required this.rooms,
  });

  int get occupiedRooms => rooms.where((r) => r.isOccupied).length;
  int get vacantRooms => totalRooms - occupiedRooms;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'totalRooms': totalRooms,
      'rooms': rooms.map((r) => r.toMap()).toList(),
    };
  }

  factory Property.fromMap(Map<String, dynamic> map) {
    return Property(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      totalRooms: map['totalRooms'] ?? 0,
      rooms: (map['rooms'] as List?)?.map((r) => Room.fromMap(r)).toList() ?? [],
    );
  }

  Property copyWith({
    String? id,
    String? name,
    String? address,
    int? totalRooms,
    List<Room>? rooms,
  }) {
    return Property(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      totalRooms: totalRooms ?? this.totalRooms,
      rooms: rooms ?? this.rooms,
    );
  }
}