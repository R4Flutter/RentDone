class AuthInputValidator {
  // ─────────────────────────────
  // NAME VALIDATION
  // ─────────────────────────────
  String? validateName(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Name is required';
    }

    if (input.trim().length < 2) {
      return 'Name is too short';
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
  // OTP VALIDATION
  // ─────────────────────────────
  String? validateOtp(String? otp) {
    if (otp == null || otp.trim().length != 6) {
      return 'Please enter a valid 6-digit OTP';
    }
    return null;
  }
}
