import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_payment/domain/exceptions/payment_exceptions.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_property_summary.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_tenant_summary.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_history_page.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';

class TenantPaymentHistoryFirebaseService {
  TenantPaymentHistoryFirebaseService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functionsAsia,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsAsia = functionsAsia ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
       _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functionsAsia;
  final FirebaseAuth _auth;

  static const int _maxPaymentAmount = 5000000;
  static const int _ownerPropertiesStreamLimit = 50;
  static const int _ownerTenantsStreamLimit = 50;
  static const int _propertyTenantsStreamLimit = 50;

  String _buildIdempotencyKey({
    required String actorUid,
    required String tenantId,
    required String propertyId,
    required int amount,
    required String method,
    DateTime? date,
    String? nonce,
  }) {
    final normalizedDate =
        date?.toUtc().toIso8601String() ??
        DateTime.now().toUtc().toIso8601String();
    final normalizedNonce = (nonce ?? '').trim();
    return [
      'v1',
      actorUid,
      tenantId,
      propertyId,
      amount.toString(),
      method.toLowerCase(),
      normalizedDate,
      normalizedNonce,
    ].join('_');
  }

  String _currentUserIdOrThrow() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('User is not authenticated.');
    }
    return uid.trim();
  }

  String _ownerIdOrThrow() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.trim().isEmpty) {
      throw StateError('Owner is not authenticated.');
    }
    return ownerId.trim();
  }

  Stream<List<OwnerPropertySummary>> watchOwnerProperties() {
    final ownerId = _ownerIdOrThrow();
    final propertiesStream = _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .limit(_ownerPropertiesStreamLimit)
        .snapshots();
    final tenantsStream = _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .limit(_ownerTenantsStreamLimit)
        .snapshots();

    return Stream<List<OwnerPropertySummary>>.multi((multi) {
      QuerySnapshot<Map<String, dynamic>>? latestProperties;
      QuerySnapshot<Map<String, dynamic>>? latestTenants;

      void emitIfReady() {
        final propertySnapshot = latestProperties;
        final tenantSnapshot = latestTenants;
        if (propertySnapshot == null || tenantSnapshot == null) {
          return;
        }

        multi.add(
          _buildOwnerPropertySummaries(
            propertySnapshot: propertySnapshot,
            tenantSnapshot: tenantSnapshot,
          ),
        );
      }

      final propertiesSub = propertiesStream.listen(
        (snapshot) {
          latestProperties = snapshot;
          emitIfReady();
        },
        onError: multi.addError,
      );

      final tenantsSub = tenantsStream.listen(
        (snapshot) {
          latestTenants = snapshot;
          emitIfReady();
        },
        onError: multi.addError,
      );

      multi.onCancel = () async {
        await propertiesSub.cancel();
        await tenantsSub.cancel();
      };
    });
  }

  Stream<List<OwnerTenantSummary>> watchPropertyTenants(String propertyId) {
    final ownerId = _ownerIdOrThrow();
    final propertyRef = _firestore.collection('properties').doc(propertyId);
    final tenantsStream = _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .where('propertyId', isEqualTo: propertyId)
      .orderBy('createdAt', descending: true)
      .limit(_propertyTenantsStreamLimit)
        .snapshots();
    final propertyStream = propertyRef.snapshots();

    return Stream<List<OwnerTenantSummary>>.multi((multi) {
      QuerySnapshot<Map<String, dynamic>>? latestTenants;
      Map<String, dynamic>? latestPropertyData;
      var hasPropertySnapshot = false;

      void emitIfReady() {
        final tenantSnapshot = latestTenants;
        if (tenantSnapshot == null || !hasPropertySnapshot) {
          return;
        }

        final roomNameById = _extractRoomNameById(latestPropertyData);
        multi.add(
          _buildOwnerTenantSummaries(
            tenantSnapshot: tenantSnapshot,
            propertyId: propertyId,
            roomNameById: roomNameById,
          ),
        );
      }

      final tenantsSub = tenantsStream.listen(
        (snapshot) {
          latestTenants = snapshot;
          emitIfReady();
        },
        onError: multi.addError,
      );

      final propertySub = propertyStream.listen(
        (snapshot) {
          hasPropertySnapshot = true;
          latestPropertyData = snapshot.data();
          emitIfReady();
        },
        onError: multi.addError,
      );

      multi.onCancel = () async {
        await tenantsSub.cancel();
        await propertySub.cancel();
      };
    });
  }

  List<OwnerPropertySummary> _buildOwnerPropertySummaries({
    required QuerySnapshot<Map<String, dynamic>> propertySnapshot,
    required QuerySnapshot<Map<String, dynamic>> tenantSnapshot,
  }) {
    final tenantsByProperty = <String, List<Map<String, dynamic>>>{};
    for (final doc in tenantSnapshot.docs) {
      final data = doc.data();
      final propertyId = (data['propertyId'] as String? ?? '').trim();
      if (propertyId.isEmpty) continue;
      tenantsByProperty
          .putIfAbsent(propertyId, () => <Map<String, dynamic>>[])
          .add(data);
    }

    final summaries = propertySnapshot.docs.map((doc) {
      final data = doc.data();
      final linkedTenants =
          tenantsByProperty[doc.id] ?? const <Map<String, dynamic>>[];
      final estimatedCollection = linkedTenants.fold<int>(
        0,
        (total, tenant) => total + ((tenant['rentAmount'] as num?)?.toInt() ?? 0),
      );

      return OwnerPropertySummary(
        id: doc.id,
        name: (data['name'] as String? ?? 'Unnamed Property').trim(),
        location: ((data['location'] ?? data['address'] ?? '') as String).trim(),
        totalTenants: linkedTenants.length,
        estimatedMonthlyCollection: estimatedCollection,
      );
    }).toList();

    summaries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return summaries;
  }

  List<OwnerTenantSummary> _buildOwnerTenantSummaries({
    required QuerySnapshot<Map<String, dynamic>> tenantSnapshot,
    required String propertyId,
    required Map<String, String> roomNameById,
  }) {
    final list = tenantSnapshot.docs.map((doc) {
      final data = doc.data();
      final isActive = data['isActive'] != false;

      return OwnerTenantSummary(
        id: doc.id,
        propertyId: propertyId,
        name: ((data['fullName'] ?? data['name'] ?? 'Tenant') as String).trim(),
        roomNumber: _resolveTenantRoomLabel(data, roomNameById),
        rentAmount: (data['rentAmount'] as num?)?.toInt() ?? 0,
        status: isActive ? 'active' : 'vacant',
        phone: ((data['phone'] ?? data['phoneNumber'] ?? '') as String).trim(),
      );
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Map<String, String> _extractRoomNameById(Map<String, dynamic>? propertyData) {
    final byId = <String, String>{};
    final roomsRaw = propertyData?['rooms'];
    if (roomsRaw is! List) return byId;

    for (final roomRaw in roomsRaw) {
      if (roomRaw is! Map) continue;

      final room = roomRaw.map((k, v) => MapEntry(k.toString(), v));
      final id = (room['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;

      final roomName = (room['name'] ?? '').toString().trim();
      final roomNumber = (room['roomNumber'] ?? '').toString().trim();
      final label = roomName.isNotEmpty ? roomName : roomNumber;

      if (label.isNotEmpty) {
        byId[id] = label;
      }
    }

    return byId;
  }

  String _resolveTenantRoomLabel(
    Map<String, dynamic> tenantData,
    Map<String, String> roomNameById,
  ) {
    final rawRoomNumber = (tenantData['roomNumber'] as String? ?? '').trim();
    final roomId = (tenantData['roomId'] as String? ?? '').trim();

    if (roomId.isNotEmpty) {
      final mappedRoomName = roomNameById[roomId]?.trim();
      if (mappedRoomName != null && mappedRoomName.isNotEmpty) {
        return mappedRoomName;
      }
    }

    if (rawRoomNumber.isNotEmpty && rawRoomNumber.toLowerCase() != 'na') {
      return rawRoomNumber;
    }

    return 'NA';
  }

  Future<TenantPaymentHistoryPage> fetchTenantPayments({
    required String tenantId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final uid = _currentUserIdOrThrow();
    final isTenantSelf = uid == tenantId.trim();

    Query<Map<String, dynamic>> query = _firestore
        .collection('payments')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('date', descending: true)
      .orderBy(FieldPath.documentId, descending: true);
    if (!isTenantSelf) {
      query = query.where('ownerId', isEqualTo: uid);
    }
    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }
    query = query.limit(limit + 1);

    final snapshot = await query.get();
    final pageDocs = snapshot.docs.take(limit).toList();
    final hasMore = snapshot.docs.length > limit;
    final items = pageDocs
        .map((doc) => TenantPaymentRecord.fromFirestore(doc.id, doc.data()))
        .toList();
    final nextCursor = hasMore && pageDocs.isNotEmpty ? pageDocs.last : null;

    return TenantPaymentHistoryPage(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  /// Add a new payment record with comprehensive validation and error handling
  /// SECURITY: Verifies tenant and property ownership before creating payment
  /// Throws PaymentException on validation or storage errors
  Future<String> addPayment({
    required String tenantId,
    required String propertyId,
    required int amount,
    required DateTime date,
    required String method,
    required String status,
    int? baseAmount,
    int? paidAmount,
    int? remainingAmount,
    String? transactionId,
    String? notes,
  }) async {
    final actorUid = _currentUserIdOrThrow();
    final normalizedTenantId = tenantId.trim();
    final normalizedPropertyId = propertyId.trim();

    if (normalizedTenantId.isEmpty) {
      throw InvalidPaymentContextException.tenantNotFound();
    }
    if (normalizedPropertyId.isEmpty) {
      throw InvalidPaymentContextException.propertyNotFound();
    }
    if (amount <= 0) {
      throw InvalidPaymentAmountException.zero();
    }
    if (amount > _maxPaymentAmount) {
      throw InvalidPaymentAmountException.custom(
        'Payment amount cannot exceed Rs $_maxPaymentAmount',
      );
    }

    final methodLower = method.trim().toLowerCase();
    final backendMethod = methodLower.contains('razorpay')
        ? 'razorpay'
        : 'manual';
    final idempotencyKey = _buildIdempotencyKey(
      actorUid: actorUid,
      tenantId: normalizedTenantId,
      propertyId: normalizedPropertyId,
      amount: amount,
      method: backendMethod,
      date: date,
      nonce: transactionId ?? notes ?? status,
    );

    try {
      final callable = _functionsAsia.httpsCallable('createPayment');
      final result = await callable.call({
        'tenantId': normalizedTenantId,
        'propertyId': normalizedPropertyId,
        'amount': amount,
        'method': backendMethod,
        'idempotencyKey': idempotencyKey,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final paymentId = (data['paymentId'] as String? ?? '').trim();
      if (paymentId.isEmpty) {
        throw PaymentStorageException.custom(
          'Payment created without payment ID',
        );
      }
      return paymentId;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw InvalidPaymentContextException.noOwnership();
      }
      if (e.code == 'unauthenticated') {
        throw InvalidPaymentContextException.noAuth();
      }
      if (e.code == 'invalid-argument') {
        throw InvalidPaymentAmountException.custom(
          e.message ?? 'Invalid payment request',
        );
      }
      if (e.code == 'already-exists') {
        throw PaymentStorageException.custom('Duplicate payment blocked');
      }
      throw PaymentStorageException.write(e);
    }
  }

  /// Update payment status (paid, partial, unpaid) with comprehensive error handling
  /// Validates status and ownership before updating
  /// Throws PaymentException on any error
  Future<void> updatePaymentStatus({
    required String paymentId,
    required String newStatus,
    int? installmentAmount,
    String? installmentMethod,
    String? installmentNotes,
  }) async {
    final normalized = newStatus.trim().toLowerCase();
    if (!['paid', 'partial', 'unpaid'].contains(normalized)) {
      throw InvalidPaymentStatusException.invalidStatus(newStatus);
    }

    try {
      final callable = _functionsAsia.httpsCallable('updatePaymentStatus');
      final payload = <String, dynamic>{
        'paymentId': paymentId.trim(),
        'newStatus': normalized,
      };
      if (installmentAmount != null) {
        payload['installmentAmount'] = installmentAmount;
      }
      if (installmentMethod != null) {
        payload['installmentMethod'] = installmentMethod;
      }
      if (installmentNotes != null) {
        payload['installmentNotes'] = installmentNotes;
      }
      await callable.call(payload);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw InvalidPaymentContextException.noOwnership();
      }
      if (e.code == 'not-found') {
        throw PaymentStorageException.notFound();
      }
      if (e.code == 'invalid-argument' || e.code == 'failed-precondition') {
        throw InvalidPaymentStatusException.invalidStatus(
          e.message ?? 'invalid',
        );
      }
      throw PaymentStorageException.update(e);
    }
  }

  /// Record a payment from Razorpay with comprehensive error handling
  /// Atomically saves payment with transaction details
  /// Returns the payment ID or throws PaymentException
  Future<String> recordRazorpayPayment({
    required String tenantId,
    required String propertyId,
    required int amount,
    required String transactionId,
    required String orderId,
    required String signature,
    DateTime? paymentDate,
    String? notes,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw InvalidPaymentContextException.tenantNotFound();
    }
    if (propertyId.trim().isEmpty) {
      throw InvalidPaymentContextException.propertyNotFound();
    }
    if (amount <= 0 || amount > _maxPaymentAmount) {
      throw InvalidPaymentAmountException.custom(
        'Payment amount must be between 1 and $_maxPaymentAmount',
      );
    }

    final paymentId = await addPayment(
      tenantId: tenantId,
      propertyId: propertyId,
      amount: amount,
      date: paymentDate ?? DateTime.now(),
      method: 'razorpay',
      status: 'pending',
      transactionId: transactionId,
      notes: notes,
    );

    try {
      final verifyCallable = _functionsAsia.httpsCallable('verifyPayment');
      await verifyCallable.call({
        'paymentId': paymentId,
        'razorpayPaymentId': transactionId.trim(),
        'razorpayOrderId': orderId.trim(),
        'razorpaySignature': signature.trim(),
      });
      return paymentId;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        throw PaymentGatewayException(
          message: 'Payment signature verification failed',
        );
      }
      throw PaymentGatewayException(
        message: e.message ?? 'Unable to verify Razorpay payment',
      );
    }
  }

  /// Verify Razorpay payment signature (server-side verification)
  /// This should typically be done on backend, but included here for completeness
  /// In production, call your backend API for verification
  Future<bool> verifyRazorpaySignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    if (orderId.trim().isEmpty ||
        paymentId.trim().isEmpty ||
        signature.trim().isEmpty) {
      return false;
    }

    throw UnimplementedError(
      'Client-side signature verification is not allowed. Use Cloud Function verifyPayment.',
    );
  }
}

