/// Validation rules for tenant management
class TenantValidator {
  /// Validate phone number format
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (!RegExp(r'^[0-9\+\-\s()]+$').hasMatch(value)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  /// Validate rent amount
  static String? validateRentAmount(int? value) {
    if (value == null || value <= 0) {
      return 'Rent amount must be greater than 0';
    }
    return null;
  }

  /// Validate lease dates
  static String? validateLeaseDates(DateTime startDate, DateTime? endDate) {
    if (endDate != null && !endDate.isAfter(startDate)) {
      return 'Lease end date must be after start date';
    }
    return null;
  }

  /// Validate rent due day
  static String? validateRentDueDay(int? value) {
    if (value == null || value < 1 || value > 31) {
      return 'Rent due day must be between 1 and 31';
    }
    return null;
  }

  /// Validate full name
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Full name is required';
    }
    if (value.length < 2) {
      return 'Full name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Full name can only contain letters and spaces';
    }
    return null;
  }

  /// Validate room number
  static String? validateRoomNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Room number is required';
    }
    return null;
  }

  /// Validate security deposit
  static String? validateSecurityDeposit(int? value) {
    if (value == null || value < 0) {
      return 'Security deposit must be 0 or greater';
    }
    return null;
  }

  /// Validate payment method
  static String? validatePaymentMethod(String? value) {
    const validMethods = ['UPI', 'cash', 'bank_transfer', 'check'];
    if (value == null || !validMethods.contains(value)) {
      return 'Invalid payment method';
    }
    return null;
  }

  /// Validate UPI ID if payment method is UPI
  static String? validateUpiId(String? upiId, String? paymentMethod) {
    if (paymentMethod == 'UPI') {
      if (upiId == null || upiId.isEmpty) {
        return 'UPI ID is required for UPI payments';
      }
      if (!RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z]+$').hasMatch(upiId)) {
        return 'Invalid UPI ID format';
      }
    }
    return null;
  }

  /// Comprehensive tenant validation
  static Map<String, String> validateTenant({
    required String fullName,
    required String phone,
    required String roomNumber,
    required int rentAmount,
    required int securityDeposit,
    required DateTime leaseStartDate,
    required DateTime? leaseEndDate,
    required int rentDueDay,
    required String paymentMethod,
    String? email,
    String? upiId,
  }) {
    final errors = <String, String>{};

    final nameError = validateFullName(fullName);
    if (nameError != null) errors['fullName'] = nameError;

    final phoneError = validatePhone(phone);
    if (phoneError != null) errors['phone'] = phoneError;

    final emailError = validateEmail(email);
    if (emailError != null) errors['email'] = emailError;

    final roomError = validateRoomNumber(roomNumber);
    if (roomError != null) errors['roomNumber'] = roomError;

    final rentError = validateRentAmount(rentAmount);
    if (rentError != null) errors['rentAmount'] = rentError;

    final depositError = validateSecurityDeposit(securityDeposit);
    if (depositError != null) errors['securityDeposit'] = depositError;

    final dateError = validateLeaseDates(leaseStartDate, leaseEndDate);
    if (dateError != null) errors['leaseDate'] = dateError;

    final dueDayError = validateRentDueDay(rentDueDay);
    if (dueDayError != null) errors['rentDueDay'] = dueDayError;

    final methodError = validatePaymentMethod(paymentMethod);
    if (methodError != null) errors['paymentMethod'] = methodError;

    final upiError = validateUpiId(upiId, paymentMethod);
    if (upiError != null) errors['upiId'] = upiError;

    return errors;
  }
}

/// Validation rules for payments
class PaymentValidator {
  /// Validate payment amount
  static String? validatePaymentAmount(int? value) {
    if (value == null || value <= 0) {
      return 'Payment amount must be greater than 0';
    }
    return null;
  }

  /// Validate payment method
  static String? validatePaymentMethod(String? value) {
    const validMethods = ['UPI', 'cash', 'bank_transfer', 'check'];
    if (value == null || !validMethods.contains(value)) {
      return 'Invalid payment method';
    }
    return null;
  }

  /// Validate month string
  static String? validateMonthFor(String? value) {
    if (value == null || value.isEmpty) {
      return 'Month is required';
    }
    // Format: "Jan 2026"
    if (!RegExp(
      r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4}$',
    ).hasMatch(value)) {
      return 'Invalid month format';
    }
    return null;
  }

  /// Comprehensive payment validation
  static Map<String, String> validatePayment({
    required int amount,
    required String monthFor,
    required String paymentMethod,
    String? referenceId,
  }) {
    final errors = <String, String>{};

    final amountError = validatePaymentAmount(amount);
    if (amountError != null) errors['amount'] = amountError;

    final monthError = validateMonthFor(monthFor);
    if (monthError != null) errors['monthFor'] = monthError;

    final methodError = validatePaymentMethod(paymentMethod);
    if (methodError != null) errors['paymentMethod'] = methodError;

    return errors;
  }
}
