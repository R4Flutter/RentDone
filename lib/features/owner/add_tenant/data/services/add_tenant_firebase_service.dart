import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

class AddTenantFirebaseService {
  final FirebaseFirestore _db;

  AddTenantFirebaseService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> addTenant(Tenant tenant) async {
    final dto = TenantDto.fromEntity(tenant);
    final tenantRef = _db.collection('tenants').doc(dto.id);
    final propertyRef = _db.collection('properties').doc(dto.propertyId);

    await _db.runTransaction((txn) async {
      final propertyDoc = await txn.get(propertyRef);
      if (!propertyDoc.exists) {
        throw StateError('Selected property does not exist');
      }

      final data = propertyDoc.data();
      final rooms = _normalizeRooms(data?['rooms']);
      final roomIndex = rooms.indexWhere((room) => room['id'] == dto.roomId);

      if (roomIndex == -1) {
        throw StateError('Selected room does not exist in this property');
      }

      final room = rooms[roomIndex];
      final currentTenantId = room['tenantId']?.toString();
      if (room['isOccupied'] == true &&
          currentTenantId != null &&
          currentTenantId.isNotEmpty) {
        throw StateError('Selected room is already occupied');
      }

      rooms[roomIndex] = {
        ...room,
        'isOccupied': true,
        'tenantId': dto.id,
      };

      txn.set(tenantRef, dto.toMap());
      txn.update(propertyRef, {'rooms': rooms});
    });
  }

  List<Map<String, dynamic>> _normalizeRooms(dynamic roomsRaw) {
    if (roomsRaw is! List) return <Map<String, dynamic>>[];

    return roomsRaw
        .whereType<Map>()
        .map((room) => Map<String, dynamic>.from(room))
        .toList();
  }
}
