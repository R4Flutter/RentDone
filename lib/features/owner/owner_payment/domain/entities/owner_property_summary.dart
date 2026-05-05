class OwnerPropertySummary {
  const OwnerPropertySummary({
    required this.id,
    required this.name,
    required this.location,
    required this.totalTenants,
    required this.estimatedMonthlyCollection,
  });

  final String id;
  final String name;
  final String location;
  final int totalTenants;
  final int estimatedMonthlyCollection;
}
