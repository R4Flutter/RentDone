import 'package:rentdone/features/owner/owners_properties/data/models/room_dto.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class PropertyDto {
  final String id;
  final String name;
  final String address;
  final int totalRooms;
  final List<RoomDto> rooms;

  const PropertyDto({
    required this.id,
    required this.name,
    required this.address,
    required this.totalRooms,
    required this.rooms,
  });

  factory PropertyDto.fromMap(Map<String, dynamic> map) {
    final roomsRaw = map['rooms'];
    final roomList = roomsRaw is List
        ? roomsRaw
              .whereType<Map>()
              .map((room) => RoomDto.fromMap(Map<String, dynamic>.from(room)))
              .toList()
        : <RoomDto>[];

    final parsedTotalRooms = _toInt(map['totalRooms']);
    final effectiveTotalRooms = parsedTotalRooms > 0
        ? parsedTotalRooms
        : roomList.length;

    return PropertyDto(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      totalRooms: effectiveTotalRooms,
      rooms: roomList,
    );
  }

  factory PropertyDto.fromEntity(Property property) {
    return PropertyDto(
      id: property.id,
      name: property.name,
      address: property.address,
      totalRooms: property.totalRooms,
      rooms: property.rooms.map(RoomDto.fromEntity).toList(),
    );
  }

  Property toEntity() {
    return Property(
      id: id,
      name: name,
      address: address,
      totalRooms: totalRooms,
      rooms: rooms.map((room) => room.toEntity()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'totalRooms': totalRooms,
      'rooms': rooms.map((room) => room.toMap()).toList(),
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
