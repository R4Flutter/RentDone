class PaymentConstants {
  const PaymentConstants._();

  static const String tenantsCollection = 'tenants';
  static const String paymentsCollection = 'payments';
  static const String usersCollection = 'users';

  static const String methodRazorpay = 'RAZORPAY';
  static const String methodCash = 'CASH';
  static const String methodUpi = 'UPI';

  static const String statusPending = 'PENDING';
  static const String statusSuccess = 'SUCCESS';
  static const String statusFailed = 'FAILED';

  static const double gatewayFeePercent = 0.02;
  static const double gstOnFeePercent = 0.18;

  static const Duration checkoutTimeout = Duration(minutes: 5);

  // Keep callable names in one place to avoid string duplication.
  static const String createRazorpayOrderCallable = 'createRazorpayOrder';
  static const String confirmRazorpayPaymentCallable = 'confirmRazorpayPayment';
}
