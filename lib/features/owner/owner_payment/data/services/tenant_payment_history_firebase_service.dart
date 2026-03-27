import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_payment/domain/exceptions/payment_exceptions.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_property_summary.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_tenant_summary.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_history_page.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';

class TenantPaymentHistoryFirebaseService {
  TenantPaymentHistoryFirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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

  /// SECURITY: Verify tenant is owned by current user before allowing operations
  /// Defense-in-depth check to prevent cross-owner tenant access
  Future<void> _verifyTenantOwnershipOrThrow({
    required String tenantId,
    required String ownerId,
  }) async {
    try {
      final tenantDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (!tenantDoc.exists) {
        throw PaymentStorageException.custom('Tenant not found: $tenantId');
      }

      final tenantOwnerId = tenantDoc.data()?['ownerId'] as String?;
      if (tenantOwnerId != ownerId) {
        throw InvalidPaymentContextException.noOwnership();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PaymentStorageException.permissionDenied();
      }
      throw PaymentStorageException.read(e);
    }
  }

  /// SECURITY: Verify property is owned by current user before allowing operations
  /// Defense-in-depth check to prevent cross-owner property access
  Future<void> _verifyPropertyOwnershipOrThrow({
    required String propertyId,
    required String ownerId,
  }) async {
    try {
      final propertyDoc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        throw PaymentStorageException.custom('Property not found: $propertyId');
      }

      final propertyOwnerId = propertyDoc.data()?['ownerId'] as String?;
      if (propertyOwnerId != ownerId) {
        throw InvalidPaymentContextException.noOwnership();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PaymentStorageException.permissionDenied();
      }
      throw PaymentStorageException.read(e);
    }
  }

  Stream<List<OwnerPropertySummary>> watchOwnerProperties() {
    final ownerId = _ownerIdOrThrow();

    return _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .asyncMap((propertySnapshot) async {
          final tenantSnapshot = await _firestore
              .collection('tenants')
              .where('ownerId', isEqualTo: ownerId)
              .get();

          final tenantsByProperty = <String, List<Map<String, dynamic>>>{};
          for (final doc in tenantSnapshot.docs) {
            final data = doc.data();
            final propertyId = (data['propertyId'] as String? ?? '').trim();
            if (propertyId.isEmpty) continue;
            tenantsByProperty
                .putIfAbsent(propertyId, () => <Map<String, dynamic>>[])
                .add(data);
          }

          return propertySnapshot.docs.map((doc) {
            final data = doc.data();
            final linkedTenants =
                tenantsByProperty[doc.id] ?? const <Map<String, dynamic>>[];
            final estimatedCollection = linkedTenants.fold<int>(
              0,
              (total, tenant) =>
                  total + ((tenant['rentAmount'] as num?)?.toInt() ?? 0),
            );

            return OwnerPropertySummary(
              id: doc.id,
              name: (data['name'] as String? ?? 'Unnamed Property').trim(),
              location: ((data['location'] ?? data['address'] ?? '') as String)
                  .trim(),
              totalTenants: linkedTenants.length,
              estimatedMonthlyCollection: estimatedCollection,
            );
          }).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        });
  }

  Stream<List<OwnerTenantSummary>> watchPropertyTenants(String propertyId) {
    final ownerId = _ownerIdOrThrow();
    final propertyRef = _firestore.collection('properties').doc(propertyId);

    return _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .asyncMap((snapshot) async {
          final propertyDoc = await propertyRef.get();
          final roomNameById = _extractRoomNameById(propertyDoc.data());

          final list =
              snapshot.docs.map((doc) {
                final data = doc.data();
                final isActive = data['isActive'] != false;

                return OwnerTenantSummary(
                  id: doc.id,
                  propertyId: propertyId,
                  name:
                      ((data['fullName'] ?? data['name'] ?? 'Tenant') as String)
                          .trim(),
                  roomNumber: _resolveTenantRoomLabel(data, roomNameById),
                  rentAmount: (data['rentAmount'] as num?)?.toInt() ?? 0,
                  status: isActive ? 'active' : 'vacant',
                  phone:
                      ((data['phone'] ?? data['phoneNumber'] ?? '') as String)
                          .trim(),
                );
              }).toList()..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

          return list;
        });
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
    DateTime? cursor,
  }) async {
    final uid = _currentUserIdOrThrow();
    final isTenantSelf = uid == tenantId.trim();

    var query = _firestore
        .collection('payments')
        .where('tenantId', isEqualTo: tenantId);
    if (!isTenantSelf) {
      query = query.where('ownerId', isEqualTo: uid);
    }

    final snapshot = await query.get();

    final sorted =
        snapshot.docs
            .map((doc) => TenantPaymentRecord.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            if (byDate != 0) return byDate;
            return b.createdAt.compareTo(a.createdAt);
          });

    final filtered = cursor == null
        ? sorted
        : sorted.where((item) => item.date.isBefore(cursor)).toList();

    final items = filtered.take(limit).toList();

    final hasMore = filtered.length > items.length;
    final nextCursor = hasMore ? items.last.date : null;

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

    final tenantDoc = await _firestore
        .collection('tenants')
        .doc(normalizedTenantId)
        .get();
    if (!tenantDoc.exists) {
      throw InvalidPaymentContextException.tenantNotFound();
    }

    final tenantData = tenantDoc.data() ?? <String, dynamic>{};
    final ownerId = (tenantData['ownerId'] as String? ?? '').trim();
    final tenantPropertyId = (tenantData['propertyId'] as String? ?? '').trim();

    final isOwnerActor = ownerId.isNotEmpty && ownerId == actorUid;
    final isTenantActor = actorUid == normalizedTenantId;

    if (!isOwnerActor && !isTenantActor) {
      throw InvalidPaymentContextException.noOwnership();
    }
    if (normalizedPropertyId.isEmpty ||
        tenantPropertyId != normalizedPropertyId) {
      throw InvalidPaymentContextException.propertyNotFound();
    }

    // For owner actor keep explicit ownership/property verification defense.
    if (isOwnerActor) {
      await _verifyTenantOwnershipOrThrow(
        tenantId: normalizedTenantId,
        ownerId: ownerId,
      );
      await _verifyPropertyOwnershipOrThrow(
        propertyId: normalizedPropertyId,
        ownerId: ownerId,
      );
    }

    // Validate inputs
    final normalizedStatus = status.trim().toLowerCase();
    if (!['paid', 'partial', 'unpaid'].contains(normalizedStatus)) {
      throw InvalidPaymentStatusException.invalidStatus(status);
    }

    if (amount <= 0) {
      throw InvalidPaymentAmountException.zero();
    }

    if (amount < 0) {
      throw InvalidPaymentAmountException.negative();
    }

    // Cap maximum payment amount (prevent outliers)
    const maxPaymentAmount = 5000000; // 50 lakhs
    if (amount > maxPaymentAmount) {
      throw InvalidPaymentAmountException.custom(
        'Payment amount cannot exceed Rs $maxPaymentAmount',
      );
    }

    // Validate date is not in future
    if (date.isAfter(DateTime.now())) {
      throw ArgumentError('Payment date cannot be in the future');
    }

    final safeBase = (baseAmount ?? amount) < amount
        ? amount
        : (baseAmount ?? amount);
    final safePaid = (paidAmount ?? (normalizedStatus == 'unpaid' ? 0 : amount))
        .clamp(0, safeBase);
    final safeRemaining = (remainingAmount ?? (safeBase - safePaid)).clamp(
      0,
      safeBase,
    );

    final docRef = _firestore.collection('payments').doc();
    final installments = <PaymentInstallment>[];
    if (safePaid > 0) {
      installments.add(
        PaymentInstallment(
          amount: safePaid,
          date: date,
          method: method.trim(),
          notes: notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
        ),
      );
    }

    final payload = TenantPaymentRecord(
      id: docRef.id,
      tenantId: normalizedTenantId,
      propertyId: normalizedPropertyId,
      amount: safeBase,
      date: date,
      method: method.trim(),
      status: safeRemaining == 0
          ? (safePaid > 0 ? 'paid' : 'unpaid')
          : (safePaid > 0 ? 'partial' : 'unpaid'),
      createdAt: DateTime.now(),
      baseAmount: safeBase,
      paidAmount: safePaid,
      remainingAmount: safeRemaining,
      transactionId: transactionId?.trim(),
      notes: notes?.trim(),
      installments: installments,
    ).toFirestore(ownerId: ownerId);

    try {
      await docRef.set(payload);
      return docRef.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw PaymentStorageException.permissionDenied();
      } else if (e.code == 'network-error' || e.code == 'unavailable') {
        throw PaymentStorageException.networkError();
      }
      throw PaymentStorageException.write(e);
    } catch (e) {
      throw PaymentStorageException.write(e as Exception?);
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
    String ownerId;
    try {
      ownerId = _ownerIdOrThrow();
    } catch (_) {
      throw InvalidPaymentContextException.noAuth();
    }

    // Validate status
    final normalized = newStatus.trim().toLowerCase();
    if (!['paid', 'partial', 'unpaid'].contains(normalized)) {
      throw InvalidPaymentStatusException.invalidStatus(newStatus);
    }

    final paymentRef = _firestore.collection('payments').doc(paymentId);
    final paymentDoc = await paymentRef.get();

    if (!paymentDoc.exists) {
      throw PaymentStorageException.notFound();
    }

    final paymentData = paymentDoc.data() ?? <String, dynamic>{};
    final paymentOwnerId = (paymentData['ownerId'] as String? ?? '').trim();

    // Verify ownership
    if (paymentOwnerId != ownerId) {
      throw InvalidPaymentContextException.noOwnership();
    }

    final baseAmount =
        (paymentData['baseAmount'] as num?)?.toInt() ??
        (paymentData['totalAmount'] as num?)?.toInt() ??
        (paymentData['amount'] as num?)?.toInt() ??
        0;
    var paidAmount = (paymentData['paidAmount'] as num?)?.toInt() ?? 0;
    final existingInstallments =
        (paymentData['installments'] as List<dynamic>? ?? const []);
    final installments = <Map<String, dynamic>>[];
    for (final item in existingInstallments) {
      if (item is Map<String, dynamic>) {
        installments.add(Map<String, dynamic>.from(item));
      } else if (item is Map) {
        installments.add(item.map((k, v) => MapEntry(k.toString(), v)));
      }
    }

    if (installments.isNotEmpty && paidAmount <= 0) {
      paidAmount = installments.fold<int>(
        0,
        (total, item) => total + ((item['amount'] as num?)?.toInt() ?? 0),
      );
    }

    if (normalized == 'partial') {
      final amount = (installmentAmount ?? 0);

      if (amount <= 0) {
        throw InvalidPaymentAmountException.zero();
      }

      final remainingBefore = (baseAmount - paidAmount).clamp(0, baseAmount);
      if (remainingBefore <= 0) {
        throw InvalidPaymentStatusException.invalidTransition(
          paymentData['status']?.toString() ?? 'unknown',
          'partial (already paid)',
        );
      }

      if (amount > remainingBefore) {
        throw InvalidPaymentAmountException.exceedsRemaining(remainingBefore);
      }

      final now = DateTime.now();
      paidAmount += amount;
      installments.add(
        PaymentInstallment(
          amount: amount,
          date: now,
          method: (installmentMethod ?? paymentData['method'] ?? 'Cash')
              .toString()
              .trim(),
          notes: installmentNotes?.trim().isNotEmpty == true
              ? installmentNotes!.trim()
              : null,
        ).toMap(),
      );
    } else if (normalized == 'paid') {
      paidAmount = baseAmount;
    } else if (normalized == 'unpaid') {
      paidAmount = 0;
      installments.clear();
    }

    final safePaid = paidAmount.clamp(0, baseAmount);
    final safeRemaining = (baseAmount - safePaid).clamp(0, baseAmount);
    final resolvedStatus = safeRemaining == 0
        ? (safePaid > 0 ? 'paid' : 'unpaid')
        : (safePaid > 0 ? 'partial' : 'unpaid');

    // Update status with error handling
    try {
      await paymentRef.update({
        'status': resolvedStatus,
        'paidAmount': safePaid,
        'remainingAmount': safeRemaining,
        'baseAmount': baseAmount,
        'installments': installments,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw InvalidPaymentContextException.noOwnership();
      } else if (e.code == 'network-error' || e.code == 'unavailable') {
        throw PaymentStorageException.networkError();
      }
      throw PaymentStorageException.update(e);
    } catch (e) {
      throw PaymentStorageException.update(e as Exception?);
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
    String ownerId;
    try {
      ownerId = _ownerIdOrThrow();
    } catch (_) {
      throw InvalidPaymentContextException.noAuth();
    }

    // Validate inputs
    if (tenantId.trim().isEmpty) {
      throw InvalidPaymentContextException.tenantNotFound();
    }
    if (propertyId.trim().isEmpty) {
      throw InvalidPaymentContextException.propertyNotFound();
    }
    if (amount <= 0) {
      throw InvalidPaymentAmountException.negative();
    }
    if (amount > 5000000) {
      throw InvalidPaymentAmountException.custom(
        'Payment amount cannot exceed Rs 5000000',
      );
    }

    final docRef = _firestore.collection('payments').doc();

    final payload = {
      'id': docRef.id,
      'tenantId': tenantId.trim(),
      'propertyId': propertyId.trim(),
      'ownerId': ownerId,
      'amount': amount,
      'baseAmount': amount,
      'paidAmount': amount,
      'remainingAmount': 0,
      'date': paymentDate ?? DateTime.now(),
      'status': 'paid', // Razorpay successful = paid
      'method': 'Razorpay',
      'transactionId': transactionId.trim(),
      'orderId': orderId.trim(),
      'signature': signature.trim(),
      'notes': notes != null && notes.trim().isNotEmpty
          ? notes.trim()
          : 'Paid via Razorpay',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'installments': [
        {
          'amount': amount,
          'date': paymentDate ?? DateTime.now(),
          'method': 'Razorpay',
          'notes': 'Razorpay payment',
        },
      ],
    };

    try {
      await docRef.set(payload);
      return docRef.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw InvalidPaymentContextException.noOwnership();
      } else if (e.code == 'network-error' || e.code == 'unavailable') {
        throw PaymentStorageException.networkError();
      }
      throw PaymentStorageException.write(e);
    } catch (e) {
      throw PaymentStorageException.write(e as Exception?);
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
