/// Represents a tenant in the RentDone system
/// Scalable, SaaS-ready entity with complete rental information
class TenantEntity {
  final String id;
  final String ownerId;
  final String propertyId;

  // Basic Information
  final String fullName;
  final String phone;
  final String? email;
  final String? profileImageUrl;
  final DateTime? dateOfBirth;

  // Rental Information
  final String roomNumber;
  final int rentAmount;
  final int securityDeposit;
  final DateTime leaseStartDate;
  final DateTime? leaseEndDate;
  final int rentDueDate; // Day of month (1-31)
  final String rentFrequency; // monthly, quarterly, annual
  final String paymentMode; // UPI, cash, bank_transfer
  final String? upiId;

  // Late Fee & Maintenance
  final double lateFinePercentage;
  final double maintenanceCharge;
  final int noticePeriodDays;

  // KYC & Documents
  final String? idProofType; // aadhar, pan, passport
  final String? idProofUrl;
  final String? agreementUrl;
  final List<String> additionalDocumentUrls;

  // Employment
  final String? companyName;
  final String? jobTitle;
  final double? monthlyIncome;

  // Emergency Contact
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelation;

  // Previous Landlord
  final String? previousLandlordName;
  final String? previousLandlordPhone;
  final String? previousAddress;

  // Verification Status
  final bool policeVerified;
  final bool backgroundChecked;

  // System Fields
  final String status; // active, inactive, notice_period, suspended
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TenantEntity({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    required this.fullName,
    required this.phone,
    required this.roomNumber,
    required this.rentAmount,
    required this.securityDeposit,
    required this.leaseStartDate,
    required this.rentDueDate,
    required this.rentFrequency,
    required this.paymentMode,
    required this.lateFinePercentage,
    required this.maintenanceCharge,
    required this.noticePeriodDays,
    required this.policeVerified,
    required this.backgroundChecked,
    required this.additionalDocumentUrls,
    required this.createdAt,
    this.email,
    this.profileImageUrl,
    this.dateOfBirth,
    this.leaseEndDate,
    this.upiId,
    this.idProofType,
    this.idProofUrl,
    this.agreementUrl,
    this.companyName,
    this.jobTitle,
    this.monthlyIncome,
    this.emergencyName,
    this.emergencyPhone,
    this.emergencyRelation,
    this.previousLandlordName,
    this.previousLandlordPhone,
    this.previousAddress,
    this.status = 'active',
    this.notes,
    this.updatedAt,
  });

  /// Check if tenant lease is active
  bool get isLeaseActive {
    final now = DateTime.now();
    return leaseStartDate.isBefore(now) &&
        (leaseEndDate == null || leaseEndDate!.isAfter(now));
  }

  /// Check if rent is overdue (today > rentDueDate and no payment)
  bool checkIfOverdue() {
    final now = DateTime.now();
    final currentMonthDueDate = DateTime(now.year, now.month, rentDueDate);
    final adjustedDueDate = currentMonthDueDate.isAfter(now)
        ? currentMonthDueDate
        : currentMonthDueDate;

    return now.isAfter(adjustedDueDate);
  }

  /// Get next rent due date
  DateTime getNextDueDate() {
    final now = DateTime.now();
    var dueDate = DateTime(now.year, now.month, rentDueDate);

    if (dueDate.isBefore(now)) {
      dueDate = DateTime(now.year, now.month + 1, rentDueDate);
    }

    return dueDate;
  }

  TenantEntity copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? fullName,
    String? phone,
    String? email,
    String? profileImageUrl,
    DateTime? dateOfBirth,
    String? roomNumber,
    int? rentAmount,
    int? securityDeposit,
    DateTime? leaseStartDate,
    DateTime? leaseEndDate,
    int? rentDueDate,
    String? rentFrequency,
    String? paymentMode,
    String? upiId,
    double? lateFinePercentage,
    double? maintenanceCharge,
    int? noticePeriodDays,
    String? idProofType,
    String? idProofUrl,
    String? agreementUrl,
    List<String>? additionalDocumentUrls,
    String? companyName,
    String? jobTitle,
    double? monthlyIncome,
    String? emergencyName,
    String? emergencyPhone,
    String? emergencyRelation,
    String? previousLandlordName,
    String? previousLandlordPhone,
    String? previousAddress,
    bool? policeVerified,
    bool? backgroundChecked,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TenantEntity(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      roomNumber: roomNumber ?? this.roomNumber,
      rentAmount: rentAmount ?? this.rentAmount,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      leaseStartDate: leaseStartDate ?? this.leaseStartDate,
      leaseEndDate: leaseEndDate ?? this.leaseEndDate,
      rentDueDate: rentDueDate ?? this.rentDueDate,
      rentFrequency: rentFrequency ?? this.rentFrequency,
      paymentMode: paymentMode ?? this.paymentMode,
      upiId: upiId ?? this.upiId,
      lateFinePercentage: lateFinePercentage ?? this.lateFinePercentage,
      maintenanceCharge: maintenanceCharge ?? this.maintenanceCharge,
      noticePeriodDays: noticePeriodDays ?? this.noticePeriodDays,
      idProofType: idProofType ?? this.idProofType,
      idProofUrl: idProofUrl ?? this.idProofUrl,
      agreementUrl: agreementUrl ?? this.agreementUrl,
      additionalDocumentUrls:
          additionalDocumentUrls ?? this.additionalDocumentUrls,
      companyName: companyName ?? this.companyName,
      jobTitle: jobTitle ?? this.jobTitle,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      emergencyName: emergencyName ?? this.emergencyName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      emergencyRelation: emergencyRelation ?? this.emergencyRelation,
      previousLandlordName: previousLandlordName ?? this.previousLandlordName,
      previousLandlordPhone:
          previousLandlordPhone ?? this.previousLandlordPhone,
      previousAddress: previousAddress ?? this.previousAddress,
      policeVerified: policeVerified ?? this.policeVerified,
      backgroundChecked: backgroundChecked ?? this.backgroundChecked,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'TenantEntity(id: $id, fullName: $fullName, phone: $phone, status: $status)';
}
