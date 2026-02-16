import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class RoomDto {
  final String id;
  final String roomNumber;
  final String name;
  final bool isOccupied;
  final String? tenantId;

  const RoomDto({
    required this.id,
    required this.roomNumber,
    required this.name,
    required this.isOccupied,
    required this.tenantId,
  });

  factory RoomDto.fromMap(Map<String, dynamic> map) {
    return RoomDto(
      id: (map['id'] ?? '').toString(),
      roomNumber: (map['roomNumber'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      isOccupied: map['isOccupied'] == true,
      tenantId: map['tenantId']?.toString(),
    );
  }

  factory RoomDto.fromEntity(Room room) {
    return RoomDto(
      id: room.id,
      roomNumber: room.roomNumber,
      name: room.name,
      isOccupied: room.isOccupied,
      tenantId: room.tenantId,
    );
  }

  Room toEntity() {
    return Room(
      id: id,
      roomNumber: roomNumber,
      name: name,
      isOccupied: isOccupied,
      tenantId: tenantId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomNumber': roomNumber,
      'name': name,
      'isOccupied': isOccupied,
      'tenantId': tenantId,
    };
  }
}
