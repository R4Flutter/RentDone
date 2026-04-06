import 'package:flutter_test/flutter_test.dart';
import 'package:rentdone/shared/validation/production_validators.dart';

void main() {
  // ---------------------------------------------------------------
  // PaymentValidator
  // ---------------------------------------------------------------
  group('PaymentValidator', () {
    group('validateAmount()', () {
      test('returns error for null', () {
        expect(PaymentValidator.validateAmount(null), isNotNull);
      });
      test('returns error for zero', () {
        expect(PaymentValidator.validateAmount(0), isNotNull);
      });
      test('returns error for negative', () {
        expect(PaymentValidator.validateAmount(-100), isNotNull);
      });
      test('returns error for exceeding max (>50 lakh)', () {
        expect(PaymentValidator.validateAmount(5000001), isNotNull);
      });
      test('returns null for valid amount', () {
        expect(PaymentValidator.validateAmount(5000), isNull);
      });
      test('returns null for boundary max', () {
        expect(PaymentValidator.validateAmount(5000000), isNull);
      });
      test('returns null for boundary min (1)', () {
        expect(PaymentValidator.validateAmount(1), isNull);
      });
    });

    group('validateInstallmentAmount()', () {
      test('rejects zero installment', () {
        expect(
          PaymentValidator.validateInstallmentAmount(
            installmentAmount: 0,
            remainingBalance: 1000,
          ),
          isNotNull,
        );
      });
      test('rejects exceeding remaining balance', () {
        expect(
          PaymentValidator.validateInstallmentAmount(
            installmentAmount: 1001,
            remainingBalance: 1000,
          ),
          isNotNull,
        );
      });
      test('accepts valid installment', () {
        expect(
          PaymentValidator.validateInstallmentAmount(
            installmentAmount: 500,
            remainingBalance: 1000,
          ),
          isNull,
        );
      });
    });

    group('validateStatus()', () {
      test('rejects null', () {
        expect(PaymentValidator.validateStatus(null), isNotNull);
      });
      test('rejects empty', () {
        expect(PaymentValidator.validateStatus(''), isNotNull);
      });
      test('rejects invalid status', () {
        expect(PaymentValidator.validateStatus('cancelled'), isNotNull);
      });
      test('accepts "paid"', () {
        expect(PaymentValidator.validateStatus('paid'), isNull);
      });
      test('accepts "Partial" (case insensitive)', () {
        expect(PaymentValidator.validateStatus('Partial'), isNull);
      });
      test('accepts "unpaid"', () {
        expect(PaymentValidator.validateStatus('unpaid'), isNull);
      });
    });

    group('validatePaymentDate()', () {
      test('rejects null', () {
        expect(PaymentValidator.validatePaymentDate(null), isNotNull);
      });
      test('rejects future date', () {
        final future = DateTime.now().add(const Duration(days: 1));
        expect(PaymentValidator.validatePaymentDate(future), isNotNull);
      });
      test('rejects date older than 2 years', () {
        final old = DateTime.now().subtract(const Duration(days: 731));
        expect(PaymentValidator.validatePaymentDate(old), isNotNull);
      });
      test('accepts today', () {
        expect(
          PaymentValidator.validatePaymentDate(DateTime.now()),
          isNull,
        );
      });
    });

    group('validatePaymentMethod()', () {
      test('rejects null', () {
        expect(PaymentValidator.validatePaymentMethod(null), isNotNull);
      });
      test('rejects invalid method', () {
        expect(PaymentValidator.validatePaymentMethod('bitcoin'), isNotNull);
      });
      test('accepts "cash"', () {
        expect(PaymentValidator.validatePaymentMethod('cash'), isNull);
      });
      test('accepts "upi"', () {
        expect(PaymentValidator.validatePaymentMethod('upi'), isNull);
      });
      test('accepts "razorpay"', () {
        expect(PaymentValidator.validatePaymentMethod('razorpay'), isNull);
      });
    });

    group('validatePaymentRecord()', () {
      test('returns empty list for valid record', () {
        final errors = PaymentValidator.validatePaymentRecord(
          amount: 5000,
          date: DateTime.now(),
          method: 'cash',
          status: 'paid',
          baseAmount: 5000,
        );
        expect(errors, isEmpty);
      });
      test('returns multiple errors for invalid record', () {
        final errors = PaymentValidator.validatePaymentRecord(
          amount: 0,
          date: DateTime.now().add(const Duration(days: 1)),
          method: 'bitcoin',
          status: 'cancelled',
          baseAmount: -1,
        );
        expect(errors.length, greaterThanOrEqualTo(4));
      });
    });
  });

  // ---------------------------------------------------------------
  // TenantValidator
  // ---------------------------------------------------------------
  group('TenantValidator', () {
    group('validateFullName()', () {
      test('rejects null', () {
        expect(TenantValidator.validateFullName(null), isNotNull);
      });
      test('rejects empty', () {
        expect(TenantValidator.validateFullName(''), isNotNull);
      });
      test('rejects single character', () {
        expect(TenantValidator.validateFullName('A'), isNotNull);
      });
      test('rejects name without space (only first name)', () {
        expect(TenantValidator.validateFullName('John'), isNotNull);
      });
      test('rejects name > 100 chars', () {
        final long = '${'A' * 50} ${'B' * 51}';
        expect(TenantValidator.validateFullName(long), isNotNull);
      });
      test('accepts valid full name', () {
        expect(TenantValidator.validateFullName('John Doe'), isNull);
      });
    });

    group('validatePhone()', () {
      test('rejects null', () {
        expect(TenantValidator.validatePhone(null), isNotNull);
      });
      test('rejects short number', () {
        expect(TenantValidator.validatePhone('12345'), isNotNull);
      });
      test('accepts 10-digit number', () {
        expect(TenantValidator.validatePhone('9876543210'), isNull);
      });
      test('accepts number with country code', () {
        expect(TenantValidator.validatePhone('+919876543210'), isNull);
      });
    });

    group('validateEmail()', () {
      test('rejects null', () {
        expect(TenantValidator.validateEmail(null), isNotNull);
      });
      test('rejects invalid format', () {
        expect(TenantValidator.validateEmail('not-an-email'), isNotNull);
      });
      test('accepts valid email', () {
        expect(TenantValidator.validateEmail('test@example.com'), isNull);
      });
    });

    group('validateRentAmount()', () {
      test('rejects null', () {
        expect(TenantValidator.validateRentAmount(null), isNotNull);
      });
      test('rejects zero', () {
        expect(TenantValidator.validateRentAmount(0), isNotNull);
      });
      test('rejects > 5 lakh', () {
        expect(TenantValidator.validateRentAmount(500001), isNotNull);
      });
      test('accepts valid rent', () {
        expect(TenantValidator.validateRentAmount(15000), isNull);
      });
    });

    group('validateSecurityDeposit()', () {
      test('allows null (optional)', () {
        expect(TenantValidator.validateSecurityDeposit(null), isNull);
      });
      test('rejects negative', () {
        expect(TenantValidator.validateSecurityDeposit(-1), isNotNull);
      });
      test('accepts zero', () {
        expect(TenantValidator.validateSecurityDeposit(0), isNull);
      });
    });

    group('validateTenantRecord()', () {
      test('returns empty for valid record', () {
        final errors = TenantValidator.validateTenantRecord(
          fullName: 'John Doe',
          phone: '9876543210',
          email: 'john@example.com',
          rentAmount: 15000,
        );
        expect(errors, isEmpty);
      });
    });
  });

  // ---------------------------------------------------------------
  // PropertyValidator
  // ---------------------------------------------------------------
  group('PropertyValidator', () {
    group('validatePropertyName()', () {
      test('rejects null', () {
        expect(PropertyValidator.validatePropertyName(null), isNotNull);
      });
      test('rejects single char', () {
        expect(PropertyValidator.validatePropertyName('A'), isNotNull);
      });
      test('rejects > 100 chars', () {
        expect(PropertyValidator.validatePropertyName('A' * 101), isNotNull);
      });
      test('accepts valid name', () {
        expect(PropertyValidator.validatePropertyName('Sunrise Apartments'), isNull);
      });
    });

    group('validateRoomCount()', () {
      test('rejects null', () {
        expect(PropertyValidator.validateRoomCount(null), isNotNull);
      });
      test('rejects zero', () {
        expect(PropertyValidator.validateRoomCount(0), isNotNull);
      });
      test('rejects > 100', () {
        expect(PropertyValidator.validateRoomCount(101), isNotNull);
      });
      test('accepts valid count', () {
        expect(PropertyValidator.validateRoomCount(5), isNull);
      });
    });

    group('validateAddress()', () {
      test('rejects null', () {
        expect(PropertyValidator.validateAddress(null), isNotNull);
      });
      test('rejects short address', () {
        expect(PropertyValidator.validateAddress('123'), isNotNull);
      });
      test('accepts valid address', () {
        expect(
          PropertyValidator.validateAddress('123 Main Street, Mumbai'),
          isNull,
        );
      });
    });

    group('validatePropertyRecord()', () {
      test('returns empty for valid record', () {
        final errors = PropertyValidator.validatePropertyRecord(
          name: 'Test Property',
          roomCount: 3,
          address: '123 Test Street, City',
        );
        expect(errors, isEmpty);
      });
      test('returns errors for invalid record', () {
        final errors = PropertyValidator.validatePropertyRecord(
          name: '',
          roomCount: 0,
          address: '',
        );
        expect(errors.length, 3);
      });
    });
  });
}
