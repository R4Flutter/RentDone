import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/features/tenant/data/models/tenant_complaint.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

class TenantFirestoreService {
  final FirebaseFirestore _firestore;

  TenantFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> ensureTenantUserDoc({
    required String uid,
    required String email,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final normalizedEmail = email.trim().toLowerCase();

    final snapshot = await userRef.get();
    if (!snapshot.exists) {
      await userRef.set({
        'uid': uid,
        'email': email,
        'emailLowercase': normalizedEmail,
        'role': 'tenant',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await userRef.set({
      'uid': uid,
      'email': email,
      'emailLowercase': normalizedEmail,
      'updatedAt': FieldValue.serverTimestamp(),
      if ((snapshot.data() ?? const <String, dynamic>{})['role'] == null)
        'role': 'tenant',
    }, SetOptions(merge: true));
  }

  Future<TenantDashboardSummary> getDashboardSummary({
    required String uid,
    String? email,
  }) async {
    Map<String, dynamic> userData = const <String, dynamic>{};
    String? tenantIdFromUser;
    Map<String, dynamic>? tenantData;
    String? resolvedTenantId;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      userData = userDoc.data() ?? const <String, dynamic>{};
      tenantIdFromUser = userData['tenantId'] as String?;
    } on FirebaseException {
      // Continue when users read fails due transient rules mismatch.
    }

    if (tenantIdFromUser != null && tenantIdFromUser.isNotEmpty) {
      try {
        final mappedDoc = await _firestore
            .collection('tenants')
            .doc(tenantIdFromUser)
            .get();
        if (mappedDoc.exists && mappedDoc.data() != null) {
          tenantData = mappedDoc.data();
          resolvedTenantId = mappedDoc.id;
        }
      } on FirebaseException {
        // Continue with fallback strategies.
      }
    }

    if (tenantData == null) {
      try {
        final byUidDoc = await _firestore.collection('tenants').doc(uid).get();
        if (byUidDoc.exists && byUidDoc.data() != null) {
          tenantData = byUidDoc.data();
          resolvedTenantId = byUidDoc.id;
        }
      } on FirebaseException {
        // Continue with fallback strategies.
      }
    }

    if (tenantData == null) {
      try {
        final byAuthUid = await _firestore
            .collection('tenants')
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();
        if (byAuthUid.docs.isNotEmpty) {
          final tenantDoc = byAuthUid.docs.first;
          tenantData = tenantDoc.data();
          resolvedTenantId = tenantDoc.id;
        }
      } on FirebaseException {
        // Keep graceful fallback.
      }
    }

    if (tenantData == null) {
      return TenantDashboardSummary(
        tenantId: '',
        tenantName: userData['name'] as String? ?? 'Tenant',
        tenantEmail:
            userData['email'] as String? ??
            userData['emailLowercase'] as String? ??
            (email ?? ''),
        tenantPhone: userData['phone'] as String? ?? '',
        ownerId: '',
        roomNumber: '-',
        propertyName: '',
        monthlyRent: 0,
        depositAmount: null,
        allocationDate: null,
        rentDueDay: 1,
        ownerPhoneNumber: '',
        dueAmount: 0,
        lifetimePaid: 0,
        currentMonthName: DateFormat.MMMM().format(DateTime.now()),
        profileImageUrl: userData['photoUrl'] as String?,
      );
    }

    final tenantId = resolvedTenantId ?? uid;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs = const [];
    try {
      final paymentsSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('payments')
          .get();
      paymentDocs = paymentsSnapshot.docs;
    } on FirebaseException {
      paymentDocs = const [];
    }

    final dynamicTotal = paymentDocs.fold<int>(
      0,
      (runningTotal, doc) =>
          runningTotal + ((doc.data()['amount'] as num?)?.toInt() ?? 0),
    );

    final monthName = DateFormat.MMMM().format(DateTime.now());
    TenantRoomDetails? roomDetails;
    TenantOwnerDetails? ownerDetails;
    try {
      roomDetails = await getRoomDetails(tenantId);
    } on FirebaseException {
      roomDetails = null;
    }
    try {
      ownerDetails = await getOwnerDetails(tenantId);
    } on FirebaseException {
      ownerDetails = null;
    }

    return TenantDashboardSummary(
      tenantId: tenantId,
      tenantName: tenantData['name'] as String? ?? 'Tenant',
      tenantEmail:
          tenantData['email'] as String? ??
          tenantData['emailLowercase'] as String? ??
          (email ?? ''),
      tenantPhone: _extractTenantPhone(
        tenantData: tenantData,
        userData: userData,
      ),
      ownerId: tenantData['ownerId'] as String? ?? '',
      roomNumber:
          roomDetails?.roomNumber ??
          (tenantData['roomNumber'] as String? ?? '-'),
      propertyName:
          roomDetails?.propertyName ??
          (tenantData['propertyName'] as String? ?? ''),
      monthlyRent:
          roomDetails?.monthlyRent ??
          ((tenantData['rentAmount'] as num?)?.toInt() ?? 0),
      depositAmount:
          roomDetails?.depositAmount ??
          ((tenantData['depositAmount'] as num?)?.toInt()),
      allocationDate: roomDetails?.allocationDate,
      rentDueDay:
          roomDetails?.rentDueDay ??
          ((tenantData['rentDueDay'] as num?)?.toInt() ?? 1),
      ownerPhoneNumber:
          ownerDetails?.ownerPhoneNumber ??
          (tenantData['ownerPhoneNumber'] as String? ?? ''),
      dueAmount: (tenantData['dueAmount'] as num?)?.toInt() ?? 0,
      lifetimePaid: (tenantData['totalPaid'] as num?)?.toInt() ?? dynamicTotal,
      currentMonthName: monthName,
      profileImageUrl: tenantData['profileImageUrl'] as String?,
    );
  }

  String _extractTenantPhone({
    required Map<String, dynamic> tenantData,
    required Map<String, dynamic> userData,
  }) {
    final candidates = <String?>[
      tenantData['phoneNumber'] as String?,
      tenantData['phone'] as String?,
      tenantData['mobile'] as String?,
      userData['phoneNumber'] as String?,
      userData['phone'] as String?,
      userData['mobile'] as String?,
    ];

    for (final candidate in candidates) {
      final normalized = (candidate ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return '';
  }

  Stream<TenantPayment?> watchCurrentMonthPayment(String tenantId) {
    final now = DateTime.now();
    final monthName = DateFormat.MMMM().format(now);
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('payments')
        .doc(monthKey)
        .snapshots()
        .asyncMap((doc) async {
          if (doc.exists) {
            return TenantPayment.fromDocument(doc);
          }

          final legacySnapshot = await _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('payments')
              .where('month', isEqualTo: monthName)
              .orderBy('paidDate', descending: true)
              .limit(1)
              .get();

          if (legacySnapshot.docs.isEmpty) {
            return null;
          }
          return TenantPayment.fromFirestore(legacySnapshot.docs.first);
        });
  }

  Future<List<TenantDocument>> getDocumentsPage(
    String tenantId, {
    String? lastDocumentId,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .limit(limit);

    if (lastDocumentId != null && lastDocumentId.isNotEmpty) {
      final lastDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('documents')
          .doc(lastDocumentId)
          .get();

      if (lastDoc.exists) {
        query = query.startAfterDocument(lastDoc);
      }
    }

    final snapshot = await query.get();
    return snapshot.docs.map(TenantDocument.fromFirestore).toList();
  }

  Future<List<TenantReminder>> getRecentReminders(
    String tenantId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('reminders')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map(TenantReminder.fromFirestore).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const <TenantReminder>[];
      }
      rethrow;
    }
  }

  Future<void> saveUploadedDocument({
    required String tenantId,
    required String fileUrl,
    required String fileType,
    required String publicId,
    required String description,
    required int fileSizeBytes,
    String? deleteToken,
  }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('documents')
        .add({
          'fileUrl': fileUrl,
          'fileType': fileType,
          'publicId': publicId,
          'uploadedAt': FieldValue.serverTimestamp(),
          'description': description,
          'fileSizeBytes': fileSizeBytes,
          if (deleteToken != null && deleteToken.isNotEmpty)
            'deleteToken': deleteToken,
        });
  }

  Future<void> deleteDocument(String tenantId, String documentId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('documents')
        .doc(documentId)
        .delete();
  }

  Future<void> saveComplaint({
    required String tenantId,
    required TenantComplaint complaint,
  }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('complaints')
        .add(complaint.toFirestore());
  }

  Future<String> getOwnerPhoneNumber(String ownerId) async {
    if (ownerId.isEmpty) return '';
    final ownerDoc = await _firestore.collection('owners').doc(ownerId).get();
    return ownerDoc.data()?['phoneNumber'] as String? ?? '';
  }

  Future<TenantRoomDetails?> getRoomDetails(String tenantId) async {
    try {
      final doc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('room_details')
          .doc('current')
          .get();

      final data = doc.data();
      if (data != null) {
        return TenantRoomDetails.fromMap(data);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
    }

    final tenantDoc = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .get();
    final tenantData = tenantDoc.data();
    if (tenantData == null) {
      return null;
    }

    final propertyName = (tenantData['propertyName'] as String? ?? '').trim();
    final roomNumber = (tenantData['roomNumber'] as String? ?? '').trim();
    final monthlyRent = (tenantData['rentAmount'] as num?)?.toInt() ?? 0;
    final rentDueDay = (tenantData['rentDueDay'] as num?)?.toInt() ?? 1;
    if (propertyName.isEmpty && roomNumber.isEmpty && monthlyRent <= 0) {
      return null;
    }

    return TenantRoomDetails(
      propertyName: propertyName,
      roomNumber: roomNumber,
      monthlyRent: monthlyRent,
      depositAmount: (tenantData['depositAmount'] as num?)?.toInt(),
      allocationDate: DateTime.now(),
      rentDueDay: rentDueDay,
    );
  }

  Future<void> saveRoomDetails({
    required String tenantId,
    required TenantRoomDetails details,
  }) async {
    if (details.monthlyRent <= 0) {
      throw Exception('Monthly rent must be greater than zero.');
    }
    if (details.rentDueDay < 1 || details.rentDueDay > 31) {
      throw Exception('Rent due day must be between 1 and 31.');
    }
    if (details.allocationDate.isAfter(DateTime.now())) {
      throw Exception('Allocation date cannot be in the future.');
    }

    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('room_details')
          .doc('current')
          .set(details.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
    }

    await _firestore.collection('tenants').doc(tenantId).set({
      'propertyName': details.propertyName,
      'roomNumber': details.roomNumber,
      'rentAmount': details.monthlyRent,
      if (details.depositAmount != null) 'depositAmount': details.depositAmount,
      'rentDueDay': details.rentDueDay,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<TenantOwnerDetails?> getOwnerDetails(String tenantId) async {
    Map<String, dynamic> ownerDetailsData = const <String, dynamic>{};
    try {
      final doc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('owner_details')
          .doc('current')
          .get();

      final data = doc.data();
      if (data != null) {
        ownerDetailsData = data;
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
    }

    final tenantDoc = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .get();

    final tenantData = tenantDoc.data() ?? const <String, dynamic>{};
    final ownerId = (tenantData['ownerId'] as String? ?? '').trim();

    Map<String, dynamic> ownerProfileData = const <String, dynamic>{};
    if (ownerId.isNotEmpty) {
      try {
        final ownerProfileDoc = await _firestore
            .collection('owners')
            .doc(ownerId)
            .get();
        ownerProfileData = ownerProfileDoc.data() ?? const <String, dynamic>{};
      } on FirebaseException {
        ownerProfileData = const <String, dynamic>{};
      }
    }

    String pickFirstNonEmpty(List<String?> values) {
      for (final value in values) {
        final normalized = (value ?? '').trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
      return '';
    }

    final resolvedPhone = pickFirstNonEmpty([
      ownerDetailsData['ownerPhoneNumber'] as String?,
      tenantData['ownerPhoneNumber'] as String?,
      ownerProfileData['phoneNumber'] as String?,
      ownerProfileData['phone'] as String?,
    ]);

    final resolvedUpiId = pickFirstNonEmpty([
      ownerDetailsData['ownerUpiId'] as String?,
      ownerDetailsData['upiId'] as String?,
      tenantData['ownerUpiId'] as String?,
      tenantData['upiId'] as String?,
      ownerProfileData['ownerUpiId'] as String?,
      ownerProfileData['upiId'] as String?,
      ownerProfileData['upi'] as String?,
    ]);

    final resolvedOwnerName = pickFirstNonEmpty([
      ownerDetailsData['ownerName'] as String?,
      tenantData['ownerName'] as String?,
      ownerProfileData['name'] as String?,
      ownerProfileData['fullName'] as String?,
    ]);

    if (resolvedPhone.isEmpty &&
        resolvedUpiId.isEmpty &&
        resolvedOwnerName.isEmpty) {
      return null;
    }

    return TenantOwnerDetails(
      ownerPhoneNumber: resolvedPhone,
      ownerUpiId: resolvedUpiId,
      ownerName: resolvedOwnerName,
    );
  }

  Future<void> saveOwnerDetails({
    required String tenantId,
    required TenantOwnerDetails details,
  }) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('owner_details')
          .doc('current')
          .set(details.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
    }

    await _firestore.collection('tenants').doc(tenantId).set({
      'ownerPhoneNumber': details.ownerPhoneNumber,
      if (details.ownerUpiId.isNotEmpty) 'ownerUpiId': details.ownerUpiId,
      if (details.ownerName.isNotEmpty) 'ownerName': details.ownerName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveTenantBasicDetails({
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
  }) async {
    final normalizedName = tenantName.trim();
    final normalizedEmail = tenantEmail.trim();
    final normalizedEmailLower = normalizedEmail.toLowerCase();
    final normalizedPhone = tenantPhone.trim();

    await _firestore.collection('tenants').doc(tenantId).set({
      'name': normalizedName,
      'email': normalizedEmail,
      'emailLowercase': normalizedEmailLower,
      'phoneNumber': normalizedPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(tenantId).set({
      'name': normalizedName,
      'email': normalizedEmail,
      'emailLowercase': normalizedEmailLower,
      'phoneNumber': normalizedPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markPaymentAsPaid({
    required String tenantId,
    required int amountPaid,
    required DateTime paymentDate,
    required String paymentMethod,
    required int monthlyRent,
  }) async {
    if (amountPaid <= 0) {
      throw Exception('Amount paid must be greater than zero.');
    }
    if (monthlyRent > 0 && amountPaid != monthlyRent) {
      throw Exception('Amount must match monthly rent for this tenant.');
    }

    final monthKey =
        '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}';
    final monthName = DateFormat.MMMM().format(paymentDate);

    final paymentRef = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('payments')
        .doc(monthKey);
    final tenantRef = _firestore.collection('tenants').doc(tenantId);

    await _firestore.runTransaction((tx) async {
      final existingPayment = await tx.get(paymentRef);
      final previousAmount =
          (existingPayment.data()?['amount'] as num?)?.toInt() ?? 0;
      final delta = amountPaid - previousAmount;

      tx.set(paymentRef, {
        'paymentMonth': monthKey,
        'month': monthName,
        'amount': amountPaid,
        'paidDate': Timestamp.fromDate(paymentDate),
        'paymentDate': Timestamp.fromDate(paymentDate),
        'paymentMethod': paymentMethod,
        'status': 'paid',
        'monthlyRentSnapshot': monthlyRent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (delta != 0) {
        tx.set(tenantRef, {
          'totalPaid': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<bool> isPaymentMarked(String tenantId, DateTime date) async {
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final snapshot = await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('payments')
        .doc(monthKey)
        .get();

    if (!snapshot.exists) {
      return false;
    }

    final status = (snapshot.data()?['status'] as String? ?? '').toLowerCase();
    return status == 'paid';
  }

  Future<void> ensureSelfTenantProfile({
    required String uid,
    required String email,
    String? displayName,
    String? phoneNumber,
  }) async {
    final tenantRef = _firestore.collection('tenants').doc(uid);
    final existing = await tenantRef.get();
    if (existing.exists) {
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final fallbackName = (displayName ?? '').trim().isNotEmpty
        ? displayName!.trim()
        : email.split('@').first;

    await tenantRef.set({
      'authUid': uid,
      'email': email,
      'emailLowercase': normalizedEmail,
      'name': fallbackName,
      'phoneNumber': (phoneNumber ?? '').trim(),
      'ownerId': '',
      'roomNumber': '-',
      'propertyName': '',
      'ownerPhoneNumber': '',
      'rentAmount': 0,
      'rentDueDay': 1,
      'dueAmount': 0,
      'totalPaid': 0,
      'isActive': false,
      'onboardingStatus': 'pending_assignment',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
