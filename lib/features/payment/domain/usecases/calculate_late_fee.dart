class CalculateLateFee {
  int call({
    required int baseAmount,
    required double percentage,
    required DateTime dueDate,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (!current.isAfter(dueDate)) return 0;
    final fee = (baseAmount * (percentage / 100)).round();
    return fee < 0 ? 0 : fee;
  }
}
