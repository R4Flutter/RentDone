String normalizeCityKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool hasValidCityKey(String? value) {
  if (value == null) return false;
  return normalizeCityKey(value).isNotEmpty;
}
