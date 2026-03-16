String normalizePhone(String phone) {
  final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

  if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
    return digitsOnly.substring(2);
  }

  if (digitsOnly.length == 10) {
    return digitsOnly;
  }

  return digitsOnly;
}
