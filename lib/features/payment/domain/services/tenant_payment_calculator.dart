import 'dart:math' as math;

enum TenantPaymentMethod { upi, card, netbanking }

class TenantPaymentQuote {
  const TenantPaymentQuote({
    required this.rentAmount,
    required this.feePercentUsed,
    required this.gstPercentUsed,
    required this.convenienceFee,
    required this.gstOnConvenienceFee,
    required this.totalPayable,
    required this.platformReceives,
    required this.currency,
  });

  final int rentAmount;
  final double feePercentUsed;
  final double gstPercentUsed;
  final int convenienceFee;
  final int gstOnConvenienceFee;
  final int totalPayable;
  final int platformReceives;
  final String currency;
}

class TenantPaymentCalculator {
  const TenantPaymentCalculator._();

  static const double _defaultGatewayFeePercent = 0.02;
  static const double _gstPercent = 0.18;

  static const Map<TenantPaymentMethod, double> _dynamicFeePercent = {
    TenantPaymentMethod.upi: 0.02,
    TenantPaymentMethod.card: 0.02,
    TenantPaymentMethod.netbanking: 0.02,
  };

  static TenantPaymentQuote calculate({
    required int rentAmount,
    TenantPaymentMethod? paymentMethod,
    String currency = 'INR',
  }) {
    final safeRent = rentAmount < 0 ? 0 : rentAmount;
    final method = paymentMethod ?? TenantPaymentMethod.netbanking;
    final feePercent = _dynamicFeePercent[method] ?? _defaultGatewayFeePercent;

    if (safeRent <= 0) {
      return TenantPaymentQuote(
        rentAmount: 0,
        feePercentUsed: feePercent,
        gstPercentUsed: _gstPercent,
        convenienceFee: 0,
        gstOnConvenienceFee: 0,
        totalPayable: 0,
        platformReceives: 0,
        currency: currency,
      );
    }

    final convenienceFee = (safeRent * feePercent).ceil();
    final gstOnConvenienceFee = (convenienceFee * _gstPercent).ceil();
    final totalPayable = safeRent + convenienceFee + gstOnConvenienceFee;

    return TenantPaymentQuote(
      rentAmount: safeRent,
      feePercentUsed: feePercent,
      gstPercentUsed: _gstPercent,
      convenienceFee: math.max(0, convenienceFee),
      gstOnConvenienceFee: math.max(0, gstOnConvenienceFee),
      totalPayable: totalPayable,
      platformReceives: safeRent,
      currency: currency,
    );
  }
}
