import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/tenant_repository_impl.dart';
import '../repositories/payment_repository_impl.dart';
import '../services/tenant_firestore_service.dart';
import '../services/payment_firestore_service.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../../domain/repositories/payment_repository.dart';

/// Firestore Service Providers
final tenantFirestoreServiceProvider = Provider<TenantFirestoreService>((ref) {
  return TenantFirestoreService();
});

final paymentFirestoreServiceProvider = Provider<PaymentFirestoreService>((
  ref,
) {
  return PaymentFirestoreService();
});

/// Repository Providers
final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  final service = ref.watch(tenantFirestoreServiceProvider);
  return TenantRepositoryImpl(service);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final service = ref.watch(paymentFirestoreServiceProvider);
  return PaymentRepositoryImpl(service);
});
