class OwnerTenantSummary {
  const OwnerTenantSummary({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.roomNumber,
    required this.rentAmount,
    required this.status,
    required this.phone,
  });

  final String id;
  final String propertyId;
  final String name;
  final String roomNumber;
  final int rentAmount;
  final String status;
  final String phone;
}
