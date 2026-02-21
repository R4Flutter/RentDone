class TenantInputValidator {
  // ─────────────────────────────
  // NAME VALIDATION
  // ─────────────────────────────
  String? validateName(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Full name is required';
    }

    if (input.trim().length < 2) {
      return 'Name is too short';
    }

    if (input.trim().length > 50) {
      return 'Name is too long';
    }

    return null;
  }

  // ─────────────────────────────
  // PHONE VALIDATION (INDIA)
  // ─────────────────────────────
  String? validatePhone(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Phone number is required';
    }

    final phone = input.trim();

    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      return 'Phone number must contain only digits';
    }

    if (phone.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }

    final firstDigit = int.tryParse(phone[0]);
    if (firstDigit == null || firstDigit < 6) {
      return 'Enter a valid Indian mobile number';
    }

    return null;
  }

  // ─────────────────────────────
  // EMAIL VALIDATION
  // ─────────────────────────────
  String? validateEmail(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null; // Email is optional
    }

    final email = input.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  // ─────────────────────────────
  // RENT AMOUNT VALIDATION
  // ─────────────────────────────
  String? validateRentAmount(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Monthly rent is required';
    }

    final rent = int.tryParse(input.trim());
    if (rent == null) {
      return 'Enter a valid amount';
    }

    if (rent <= 0) {
      return 'Rent must be greater than 0';
    }

    if (rent > 1000000) {
      return 'Rent amount seems too high';
    }

    return null;
  }

  // ─────────────────────────────
  // SECURITY DEPOSIT VALIDATION
  // ─────────────────────────────
  String? validateSecurityDeposit(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Security deposit is required';
    }

    final deposit = int.tryParse(input.trim());
    if (deposit == null) {
      return 'Enter a valid amount';
    }

    if (deposit < 0) {
      return 'Security deposit cannot be negative';
    }

    if (deposit > 5000000) {
      return 'Security deposit seems too high';
    }

    return null;
  }

  // ─────────────────────────────
  // MONTHLY INCOME VALIDATION
  // ─────────────────────────────
  String? validateMonthlyIncome(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null; // Optional
    }

    final income = double.tryParse(input.trim());
    if (income == null) {
      return 'Enter a valid amount';
    }

    if (income < 0) {
      return 'Income cannot be negative';
    }

    if (income > 10000000) {
      return 'Income amount seems too high';
    }

    return null;
  }

  String? validateRentDueDay(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Rent due day is required';
    }

    final day = int.tryParse(input.trim());
    if (day == null) {
      return 'Enter a valid day';
    }

    if (day < 1 || day > 31) {
      return 'Rent due day must be between 1 and 31';
    }

    return null;
  }

  String? validateUpiId(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Owner UPI ID is required';
    }

    final upiId = input.trim();
    final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$');
    if (!upiRegex.hasMatch(upiId)) {
      return 'Enter a valid UPI ID (example@bank)';
    }

    return null;
  }

  // ─────────────────────────────
  // EMERGENCY CONTACT NAME VALIDATION
  // ─────────────────────────────
  String? validateEmergencyName(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null; // Optional
    }

    if (input.trim().length < 2) {
      return 'Emergency contact name is too short';
    }

    if (input.trim().length > 50) {
      return 'Emergency contact name is too long';
    }

    return null;
  }

  // ─────────────────────────────
  // EMERGENCY CONTACT PHONE VALIDATION
  // ─────────────────────────────
  String? validateEmergencyPhone(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null; // Optional
    }

    final phone = input.trim();

    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      return 'Emergency phone number must contain only digits';
    }

    if (phone.length != 10) {
      return 'Enter a valid 10-digit emergency phone number';
    }

    final firstDigit = int.tryParse(phone[0]);
    if (firstDigit == null || firstDigit < 6) {
      return 'Enter a valid Indian emergency phone number';
    }

    return null;
  }

  // ─────────────────────────────
  // DOCUMENTS VALIDATION
  // ─────────────────────────────
  String? validateDocuments(List<String> documentUrls) {
    if (documentUrls.length < 2) {
      return 'Please upload at least 2 documents';
    }

    if (documentUrls.length > 5) {
      return 'Maximum 5 documents allowed';
    }

    return null;
  }
}
