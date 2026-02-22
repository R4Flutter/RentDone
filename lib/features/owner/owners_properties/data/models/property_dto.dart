import 'package:rentdone/features/owner/owners_properties/data/models/room_dto.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class PropertyDto {
  final String id;
  final String name;
  final String address;
  final int totalRooms;
  final List<RoomDto> rooms;

  /// ✅ Added for tenant map
  final String city;
  final double lat;
  final double lng;

  /// ✅ Controls tenant visibility
  final bool isPublished;

  const PropertyDto({
    required this.id,
    required this.name,
    required this.address,
    required this.totalRooms,
    required this.rooms,
    required this.city,
    required this.lat,
    required this.lng,
    required this.isPublished,
  });

  factory PropertyDto.fromMap(Map<String, dynamic> map) {
    final roomsRaw = map['rooms'];
    final roomList = roomsRaw is List
        ? roomsRaw
            .whereType<Map>()
            .map((room) => RoomDto.fromMap(Map<String, dynamic>.from(room)))
            .toList()
        : <RoomDto>[];

    return PropertyDto(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      totalRooms: _toInt(map['totalRooms']),
      rooms: roomList,

      // ✅ Safe defaults if older docs don't have these
      city: (map['city'] ?? '').toString(),
      lat: _toDouble(map['lat']),
      lng: _toDouble(map['lng']),
      isPublished: _toBool(map['isPublished']),
    );
  }

  factory PropertyDto.fromEntity(Property property) {
    return PropertyDto(
      id: property.id,
      name: property.name,
      address: property.address,
      totalRooms: property.totalRooms,
      rooms: property.rooms.map(RoomDto.fromEntity).toList(),
      city: property.city,
      lat: property.lat,
      lng: property.lng,
      isPublished: property.isPublished,
    );
  }

  Property toEntity() {
    return Property(
      id: id,
      name: name,
      address: address,
      totalRooms: totalRooms,
      rooms: rooms.map((room) => room.toEntity()).toList(),
      city: city,
      lat: lat,
      lng: lng,
      isPublished: isPublished,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'totalRooms': totalRooms,
      'rooms': rooms.map((room) => room.toMap()).toList(),
      'city': city,
      'lat': lat,
      'lng': lng,
      'isPublished': isPublished,
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    final s = (value ?? '').toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }
}