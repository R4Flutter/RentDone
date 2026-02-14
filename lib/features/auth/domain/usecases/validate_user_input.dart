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
  // EMAIL VALIDATION
  // ─────────────────────────────
  String? validateEmail(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Email is required';
    }

    final email = input.trim();
    // Basic email regex
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
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
