/// Production-ready input validation for payment and tenant operations
/// Centralizes all validation logic with user-friendly error messages
library;

class PaymentValidator {
  /// Validate payment amount
  /// Returns error message or null if valid
  static String? validateAmount(int? amount) {
    if (amount == null) {
      return 'Amount is required';
    }
    if (amount <= 0) {
      return 'Amount must be greater than zero';
    }
    if (amount > 5000000) {
      return 'Amount cannot exceed Rs 50,00,000';
    }
    return null;
  }

  /// Validate remaining balance for installment
  /// Returns error message or null if valid
  static String? validateInstallmentAmount({
    required int installmentAmount,
    required int remainingBalance,
  }) {
    if (installmentAmount <= 0) {
      return 'Installment amount must be greater than zero';
    }
    if (installmentAmount > remainingBalance) {
      return 'Installment cannot exceed remaining amount (Rs $remainingBalance)';
    }
    return null;
  }

  /// Validate payment status
  /// Returns error message or null if valid
  static String? validateStatus(String? status) {
    if (status == null || status.isEmpty) {
      return 'Payment status is required';
    }
    const validStatuses = ['paid', 'partial', 'unpaid'];
    if (!validStatuses.contains(status.toLowerCase())) {
      return 'Invalid payment status. Must be: paid, partial, or unpaid';
    }
    return null;
  }

  /// Validate payment date (must not be in future)
  /// Returns error message or null if valid
  static String? validatePaymentDate(DateTime? date) {
    if (date == null) {
      return 'Payment date is required';
    }
    if (date.isAfter(DateTime.now())) {
      return 'Payment date cannot be in the future';
    }
    // Check if date is more than 2 years in past (suspicious)
    final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
    if (date.isBefore(twoYearsAgo)) {
      return 'Payment date is too old (more than 2 years)';
    }
    return null;
  }

  /// Validate payment method
  /// Returns error message or null if valid
  static String? validatePaymentMethod(String? method) {
    if (method == null || method.trim().isEmpty) {
      return 'Payment method is required';
    }
    const validMethods = ['cash', 'upi', 'razorpay', 'online', 'check'];
    if (!validMethods.contains(method.toLowerCase())) {
      return 'Invalid payment method: $method';
    }
    return null;
  }

  /// Validate base rent amount
  /// Returns error message or null if valid
  static String? validateBaseAmount(int? amount) {
    if (amount == null) {
      return 'Base amount is required';
    }
    if (amount <= 0) {
      return 'Base amount must be greater than zero';
    }
    if (amount > 500000) {
      return 'Base amount seems unusually high (>Rs 5,00,000). Please verify.';
    }
    return null;
  }

  /// Validate entire payment record
  /// Returns list of error messages (empty if all valid)
  static List<String> validatePaymentRecord({
    required int amount,
    required DateTime date,
    required String method,
    required String status,
    required int baseAmount,
  }) {
    final errors = <String>[];

    final amountError = validateAmount(amount);
    if (amountError != null) errors.add(amountError);

    final dateError = validatePaymentDate(date);
    if (dateError != null) errors.add(dateError);

    final methodError = validatePaymentMethod(method);
    if (methodError != null) errors.add(methodError);

    final statusError = validateStatus(status);
    if (statusError != null) errors.add(statusError);

    final baseError = validateBaseAmount(baseAmount);
    if (baseError != null) errors.add(baseError);

    return errors;
  }
}

class TenantValidator {
  /// Validate tenant full name
  static String? validateFullName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Full name is required';
    }
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (trimmed.length > 100) {
      return 'Name must be less than 100 characters';
    }
    // Check for at least one space (first and last name)
    if (!trimmed.contains(' ')) {
      return 'Please enter both first name and last name';
    }
    return null;
  }

  /// Validate tenant phone number
  static String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return 'Phone number is required';
    }
    final trimmed = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (trimmed.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (trimmed.length > 15) {
      return 'Phone number is too long';
    }
    return null;
  }

  /// Validate tenant email
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    );
    if (!emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate rent amount
  static String? validateRentAmount(int? amount) {
    if (amount == null) {
      return 'Rent amount is required';
    }
    if (amount <= 0) {
      return 'Rent amount must be greater than zero';
    }
    if (amount > 500000) {
      return 'Rent amount seems unusually high (>Rs 5,00,000). Please verify.';
    }
    return null;
  }

  /// Validate security deposit
  static String? validateSecurityDeposit(int? amount) {
    if (amount == null) return null; // Optional field
    if (amount < 0) {
      return 'Security deposit cannot be negative';
    }
    if (amount > 5000000) {
      return 'Security deposit seems unusually high';
    }
    return null;
  }

  /// Validate lease start date
  static String? validateLeaseDate(DateTime? date) {
    if (date == null) {
      return 'Lease start date is required';
    }
    // Can be today or past, but not future
    if (date.isAfter(DateTime.now())) {
      return 'Lease date cannot be in the future';
    }
    return null;
  }

  /// Validate entire tenant record
  static List<String> validateTenantRecord({
    required String fullName,
    required String phone,
    required String email,
    required int rentAmount,
    DateTime? leaseStartDate,
    int? securityDeposit,
  }) {
    final errors = <String>[];

    final nameError = validateFullName(fullName);
    if (nameError != null) errors.add(nameError);

    final phoneError = validatePhone(phone);
    if (phoneError != null) errors.add(phoneError);

    final emailError = validateEmail(email);
    if (emailError != null) errors.add(emailError);

    final rentError = validateRentAmount(rentAmount);
    if (rentError != null) errors.add(rentError);

    if (leaseStartDate != null) {
      final dateError = validateLeaseDate(leaseStartDate);
      if (dateError != null) errors.add(dateError);
    }

    final depositError = validateSecurityDeposit(securityDeposit);
    if (depositError != null) errors.add(depositError);

    return errors;
  }
}

class PropertyValidator {
  /// Validate property name
  static String? validatePropertyName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Property name is required';
    }
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      return 'Property name must be at least 2 characters';
    }
    if (trimmed.length > 100) {
      return 'Property name must be less than 100 characters';
    }
    return null;
  }

  /// Validate room count
  static String? validateRoomCount(int? count) {
    if (count == null) {
      return 'Number of rooms is required';
    }
    if (count < 1) {
      return 'Property must have at least 1 room';
    }
    if (count > 100) {
      return 'Number of rooms seems unreasonable';
    }
    return null;
  }

  /// Validate property address
  static String? validateAddress(String? address) {
    if (address == null || address.trim().isEmpty) {
      return 'Address is required';
    }
    if (address.trim().length < 5) {
      return 'Please enter a complete address';
    }
    return null;
  }

  /// Validate entire property record
  static List<String> validatePropertyRecord({
    required String name,
    required int roomCount,
    required String address,
  }) {
    final errors = <String>[];

    final nameError = validatePropertyName(name);
    if (nameError != null) errors.add(nameError);

    final roomError = validateRoomCount(roomCount);
    if (roomError != null) errors.add(roomError);

    final addressError = validateAddress(address);
    if (addressError != null) errors.add(addressError);

    return errors;
  }
}
