import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/payment/data/datasources/payment_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/datasources/payment_functions_datasource.dart';
import 'package:rentdone/features/payment/data/models/transaction_record_dto.dart';
import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentFirestoreDataSource _firestore;
  final PaymentFunctionsDataSource _functions;
  final FirebaseAuth _auth;

  PaymentRepositoryImpl(this._firestore, this._functions, this._auth);

  @override
  Future<PaymentDue?> getCurrentDue({required String tenantId}) async {
    try {
      final lease = await _firestore.getActiveLeaseForTenant(tenantId);
      if (lease == null) return null;

      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final payment = await _firestore.getPaymentForLeaseMonth(
        leaseId: lease['id'] as String,
        month: month,
        year: year,
      );

      final rentAmount = (lease['rentAmount'] as num?)?.toInt() ?? 0;
      final lateFeePercentage =
          (lease['lateFeePercentage'] as num?)?.toDouble() ?? 0.0;
      final dueDate = _toDate(lease['dueDate']) ?? now;

      final isOverdue = now.isAfter(dueDate);
      final lateFeeAmount = isOverdue
          ? (rentAmount * (lateFeePercentage / 100)).round()
          : 0;
      final totalAmount = rentAmount + lateFeeAmount;
      final daysRemaining = dueDate
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      final propertyName = (lease['propertyName'] as String?) ?? 'Property';
      final ownerName = (lease['ownerName'] as String?) ?? 'Owner';
      final paymentId = (payment?['id'] as String?) ?? '';
      final receiptUrl = payment?['receiptUrl'] as String?;
      final status = (payment?['status'] as String?) ?? 'pending';
      final lastTransaction = paymentId.isNotEmpty
          ? await _firestore.getLatestTransactionForPayment(paymentId)
          : null;

      return PaymentDue(
        leaseId: lease['id'] as String,
        paymentId: paymentId,
        tenantId: tenantId,
        ownerId: (lease['ownerId'] as String?) ?? '',
        propertyId: (lease['propertyId'] as String?) ?? '',
        propertyName: propertyName,
        ownerName: ownerName,
        monthlyRent: rentAmount,
        dueDate: dueDate,
        lateFeeAmount: lateFeeAmount,
        totalPayable: totalAmount,
        daysRemaining: daysRemaining,
        paymentStatus: status,
        lastTransactionStatus: lastTransaction?['status'] as String?,
        receiptUrl: receiptUrl,
      );
    } on FirebaseException catch (error) {
      throw _mapFirebaseFailure(error);
    } catch (error) {
      throw const ServerFailure('Failed to load due payment');
    }
  }

  @override
  Future<PaymentIntent> createPaymentIntent({
    required String leaseId,
    required int month,
    required int year,
    required String gateway,
    required String idempotencyKey,
  }) async {
    _requireAuth();
    try {
      final dto = await _functions.createPaymentIntent(
        leaseId: leaseId,
        month: month,
        year: year,
        gateway: gateway,
        idempotencyKey: idempotencyKey,
      );
      return dto.toEntity();
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsFailure(error);
    } catch (error) {
      throw const ServerFailure('Unable to create payment intent');
    }
  }

  @override
  Future<void> verifyPayment({
    required String paymentId,
    required String gateway,
    required Map<String, dynamic> payload,
  }) async {
    _requireAuth();
    try {
      await _functions.verifyPayment(
        paymentId: paymentId,
        gateway: gateway,
        payload: payload,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _mapFunctionsFailure(error);
    } catch (error) {
      throw const ServerFailure('Payment verification failed');
    }
  }

  @override
  Future<TransactionPage> getTransactionHistory({
    required TransactionActor actor,
    required String actorId,
    required int limit,
    int? year,
    String? status,
    DateTime? startAfterCreatedAt,
    String? startAfterDocId,
  }) async {
    try {
      final field = actor == TransactionActor.tenant ? 'tenantId' : 'ownerId';
      final snap = await _firestore.getTransactions(
        field: field,
        value: actorId,
        limit: limit,
        year: year,
        status: status,
        startAfterCreatedAt: startAfterCreatedAt,
        startAfterDocId: startAfterDocId,
      );

      final filteredDocs =
          snap.docs.where((doc) {
            final data = doc.data();

            if (year != null) {
              final createdAt = _toDate(data['createdAt']);
              if (createdAt == null || createdAt.year != year) {
                return false;
              }
            }

            if (status != null && status.isNotEmpty && status != 'all') {
              final recordStatus = (data['status'] as String? ?? '').trim();
              if (recordStatus != status) {
                return false;
              }
            }

            return true;
          }).toList()..sort((left, right) {
            final leftDate =
                _toDate(left.data()['createdAt']) ?? DateTime(1970);
            final rightDate =
                _toDate(right.data()['createdAt']) ?? DateTime(1970);
            final dateCompare = rightDate.compareTo(leftDate);
            if (dateCompare != 0) {
              return dateCompare;
            }
            return right.id.compareTo(left.id);
          });

      List<QueryDocumentSnapshot<Map<String, dynamic>>> pagedDocs =
          filteredDocs;
      if (startAfterCreatedAt != null && startAfterDocId != null) {
        pagedDocs = filteredDocs.where((doc) {
          final createdAt = _toDate(doc.data()['createdAt']);
          if (createdAt == null) {
            return false;
          }
          if (createdAt.isBefore(startAfterCreatedAt)) {
            return true;
          }
          if (createdAt.isAtSameMomentAs(startAfterCreatedAt)) {
            return doc.id.compareTo(startAfterDocId) < 0;
          }
          return false;
        }).toList();
      }

      final limitedDocs = pagedDocs.take(limit).toList();

      final items = limitedDocs
          .map(
            (doc) => TransactionRecordDto.fromFirestore(
              doc.id,
              doc.data(),
            ).toEntity(),
          )
          .toList();

      final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      final lastCreated = lastDoc?.data()['createdAt'];
      final lastDate = _toDate(lastCreated);

      return TransactionPage(
        items: items,
        nextCreatedAt: lastDate,
        nextDocId: lastDoc?.id,
        hasMore: pagedDocs.length > limit,
      );
    } on FirebaseException catch (error) {
      throw _mapFirebaseFailure(error);
    } catch (error) {
      throw const ServerFailure('Unable to load transactions');
    }
  }

  @override
  Future<bool> preventDuplicatePayment({
    required String leaseId,
    required int month,
    required int year,
  }) async {
    try {
      final existing = await _firestore.getPaymentForLeaseMonth(
        leaseId: leaseId,
        month: month,
        year: year,
      );

      if (existing == null) return false;
      final status = (existing['status'] as String?) ?? '';
      return status == 'paid' || status == 'success';
    } on FirebaseException catch (error) {
      throw _mapFirebaseFailure(error);
    } catch (error) {
      throw const ServerFailure('Unable to check payment status');
    }
  }

  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw const UnauthorizedFailure();
    }
  }

  PaymentFailure _mapFirebaseFailure(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return const UnauthorizedFailure();
      case 'unavailable':
        return const NetworkFailure();
      default:
        return ServerFailure(error.message ?? 'Database error');
    }
  }

  PaymentFailure _mapFunctionsFailure(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return const UnauthorizedFailure();
      case 'unavailable':
        return const NetworkFailure();
      case 'invalid-argument':
        return ValidationFailure(error.message ?? 'Invalid input');
      case 'not-found':
        return NotFoundFailure(error.message ?? 'Not found');
      default:
        return ServerFailure(error.message ?? 'Function error');
    }
  }

  DateTime? _toDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
