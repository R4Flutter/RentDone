import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';

import 'tenant_owner_raw_data_reader.dart';
import 'tenant_owner_value_picker.dart';

class TenantOwnerDetailsReader {
  final FirebaseFirestore firestore;

  const TenantOwnerDetailsReader(this.firestore);

  Future<String> getOwnerPhoneNumber(String ownerId) async {
    if (ownerId.isEmpty) return '';
    final ownerDoc = await firestore.collection('owners').doc(ownerId).get();
    return ownerDoc.data()?['phoneNumber'] as String? ?? '';
  }

  Future<TenantOwnerDetails?> get(String tenantId) async {
    final rawReader = TenantOwnerRawDataReader(firestore);
    final ownerDetailsData = await rawReader.currentDetails(tenantId);
    final tenantData =
        (await firestore.collection('tenants').doc(tenantId).get()).data() ??
        const <String, dynamic>{};
    final ownerId = (tenantData['ownerId'] as String? ?? '').trim();
    final ownerProfileData = ownerId.isEmpty
        ? const <String, dynamic>{}
        : await rawReader.ownerProfile(ownerId);

    final phone = pickOwnerValue([
      ownerDetailsData['ownerPhoneNumber'],
      tenantData['ownerPhoneNumber'],
      ownerProfileData['phoneNumber'],
      ownerProfileData['phone'],
    ]);
    final upi = pickOwnerValue([
      ownerDetailsData['ownerUpiId'],
      ownerDetailsData['upiId'],
      tenantData['ownerUpiId'],
      tenantData['upiId'],
      ownerProfileData['ownerUpiId'],
      ownerProfileData['upiId'],
      ownerProfileData['upi'],
    ]);
    final name = pickOwnerValue([
      ownerDetailsData['ownerName'],
      tenantData['ownerName'],
      ownerProfileData['name'],
      ownerProfileData['fullName'],
    ]);
    return phone.isEmpty && upi.isEmpty && name.isEmpty
        ? null
        : TenantOwnerDetails(
            ownerPhoneNumber: phone,
            ownerUpiId: upi,
            ownerName: name,
          );
  }
}
