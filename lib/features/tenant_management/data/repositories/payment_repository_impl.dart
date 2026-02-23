import '../../domain/entities/payment_entity.dart';
import '../../domain/repositories/payment_repository.dart';
import '../models/payment_dto.dart';
import '../services/payment_firestore_service.dart';

/// Implementation of PaymentRepository
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentFirestoreService _firebaseService;

  PaymentRepositoryImpl(this._firebaseService);

  @override
  Future<void> recordPayment(PaymentEntity payment) async {
    try {
      final dto = PaymentDTO.fromEntity(payment);
      await _firebaseService.recordPayment(dto);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<PaymentEntity>> getPaymentHistory(
    String tenantId, {
    required int limit,
    required int page,
  }) async {
    try {
      final dtos = await _firebaseService.getPaymentHistory(
        tenantId,
        limit: limit,
        page: page,
      );
      return dtos.map((dto) => dto.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<PaymentEntity>> getPendingPayments(String ownerId) async {
    try {
      final dtos = await _firebaseService.getPendingPayments(ownerId);
      return dtos.map((dto) => dto.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<PaymentEntity>> getPaymentsByMonth(
    String ownerId,
    String monthFor,
  ) async {
    try {
      final dtos = await _firebaseService.getPaymentsByMonth(ownerId, monthFor);
      return dtos.map((dto) => dto.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePaymentStatus(String paymentId, String status) async {
    try {
      await _firebaseService.updatePaymentStatus(paymentId, status);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getMonthlyRevenue(String ownerId) async {
    try {
      return await _firebaseService.getMonthlyRevenue(ownerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getPendingAmount(String ownerId) async {
    try {
      return await _firebaseService.getPendingAmount(ownerId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> getOverdueAmount(String ownerId) async {
    try {
      return await _firebaseService.getOverdueAmount(ownerId);
    } catch (e) {
      rethrow;
    }
  }
}
