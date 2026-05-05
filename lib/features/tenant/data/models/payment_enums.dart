import 'package:rentdone/features/tenant/data/services/payment_constants.dart';

enum PaymentMethodType { razorpay, cash, upi }

extension PaymentMethodTypeX on PaymentMethodType {
  String get dbValue {
    switch (this) {
      case PaymentMethodType.razorpay:
        return PaymentConstants.methodRazorpay;
      case PaymentMethodType.cash:
        return PaymentConstants.methodCash;
      case PaymentMethodType.upi:
        return PaymentConstants.methodUpi;
    }
  }

  static PaymentMethodType fromDb(String raw) {
    switch (raw.toUpperCase().trim()) {
      case PaymentConstants.methodRazorpay:
        return PaymentMethodType.razorpay;
      case PaymentConstants.methodCash:
        return PaymentMethodType.cash;
      case PaymentConstants.methodUpi:
        return PaymentMethodType.upi;
      default:
        return PaymentMethodType.upi;
    }
  }
}

enum PaymentStatusType { pending, success, failed }

extension PaymentStatusTypeX on PaymentStatusType {
  String get dbValue {
    switch (this) {
      case PaymentStatusType.pending:
        return PaymentConstants.statusPending;
      case PaymentStatusType.success:
        return PaymentConstants.statusSuccess;
      case PaymentStatusType.failed:
        return PaymentConstants.statusFailed;
    }
  }

  static PaymentStatusType fromDb(String raw) {
    switch (raw.toUpperCase().trim()) {
      case PaymentConstants.statusPending:
        return PaymentStatusType.pending;
      case PaymentConstants.statusSuccess:
        return PaymentStatusType.success;
      case PaymentConstants.statusFailed:
        return PaymentStatusType.failed;
      default:
        return PaymentStatusType.pending;
    }
  }
}
