import 'package:rentdone/features/payment/data/repositories/payment_duplicate_checker.dart';

mixin PaymentRepositoryDuplicateMixin {
  PaymentDuplicateChecker get duplicateChecker;

  Future<bool> preventDuplicatePayment({
    required String leaseId,
    required int month,
    required int year,
  }) =>
      duplicateChecker.isDuplicate(leaseId: leaseId, month: month, year: year);
}
