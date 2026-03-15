String pickOwnerValue(List<Object?> values) {
  for (final value in values) {
    final normalized = (value as String? ?? '').trim();
    if (normalized.isNotEmpty) return normalized;
  }
  return '';
}
