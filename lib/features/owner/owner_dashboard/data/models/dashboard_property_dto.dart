class DashboardPropertyDto {
  final String id;
  final List<Map<String, dynamic>> rooms;

  const DashboardPropertyDto({
    required this.id,
    required this.rooms,
  });

  factory DashboardPropertyDto.fromMap(String id, Map<String, dynamic> map) {
    final roomsRaw = map['rooms'];
    final rooms = roomsRaw is List
        ? roomsRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    return DashboardPropertyDto(id: id, rooms: rooms);
  }

  int get vacantRooms {
    final occupied = rooms.where((room) => room['isOccupied'] == true).length;
    return (rooms.length - occupied).clamp(0, rooms.length);
  }
}
