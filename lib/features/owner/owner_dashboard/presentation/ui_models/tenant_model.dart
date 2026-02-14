

class Tenant {
  final String id;

  // Basic Info
  final String fullName;
  final String phone;
  final String? alternatePhone;
  final String? email;
  final DateTime? dateOfBirth;
  final String tenantType; // Individual / Family / Company

  // KYC
  final String? primaryIdType;
  final String? primaryIdNumber;
  final String? aadhaarNumber;
  final String? panNumber;
  final String? photoUrl;
  final String? idDocumentUrl;

  // Employment
  final String? companyName;
  final String? jobTitle;
  final String? officeAddress;
  final double? monthlyIncome;

  // Rental Info
  final String propertyId;
  final String roomId;
  final DateTime moveInDate;
  final DateTime? agreementEndDate;
  final int rentAmount;
  final int securityDeposit;
  final String rentFrequency; // Monthly / Weekly
  final int rentDueDay;
  final String paymentMode; // UPI / Bank / Cash
  final double lateFinePercentage;
  final int noticePeriodDays;
  final double maintenanceCharge;

  // Emergency Contact
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelation;

  // Previous Address
  final String? previousAddress;
  final String? previousLandlordName;
  final String? previousLandlordPhone;

  // Verification
  final bool policeVerified;
  final bool backgroundChecked;

  // System Fields
  final bool isActive;
  final DateTime createdAt;

  Tenant({
    required this.id,
    required this.fullName,
    required this.phone,
    this.alternatePhone,
    this.email,
    this.dateOfBirth,
    required this.tenantType,
    this.primaryIdType,
    this.primaryIdNumber,
    this.aadhaarNumber,
    this.panNumber,
    this.photoUrl,
    this.idDocumentUrl,
    this.companyName,
    this.jobTitle,
    this.officeAddress,
    this.monthlyIncome,
    required this.propertyId,
    required this.roomId,
    required this.moveInDate,
    this.agreementEndDate,
    required this.rentAmount,
    required this.securityDeposit,
    required this.rentFrequency,
    required this.rentDueDay,
    required this.paymentMode,
    required this.lateFinePercentage,
    required this.noticePeriodDays,
    required this.maintenanceCharge,
    this.emergencyName,
    this.emergencyPhone,
    this.emergencyRelation,
    this.previousAddress,
    this.previousLandlordName,
    this.previousLandlordPhone,
    required this.policeVerified,
    required this.backgroundChecked,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "fullName": fullName,
      "phone": phone,
      "alternatePhone": alternatePhone,
      "email": email,
      "dateOfBirth": dateOfBirth,
      "tenantType": tenantType,
      "primaryIdType": primaryIdType,
      "primaryIdNumber": primaryIdNumber,
      "aadhaarNumber": aadhaarNumber,
      "panNumber": panNumber,
      "photoUrl": photoUrl,
      "idDocumentUrl": idDocumentUrl,
      "companyName": companyName,
      "jobTitle": jobTitle,
      "officeAddress": officeAddress,
      "monthlyIncome": monthlyIncome,
      "propertyId": propertyId,
      "roomId": roomId,
      "moveInDate": moveInDate,
      "agreementEndDate": agreementEndDate,
      "rentAmount": rentAmount,
      "securityDeposit": securityDeposit,
      "rentFrequency": rentFrequency,
      "rentDueDay": rentDueDay,
      "paymentMode": paymentMode,
      "lateFinePercentage": lateFinePercentage,
      "noticePeriodDays": noticePeriodDays,
      "maintenanceCharge": maintenanceCharge,
      "emergencyName": emergencyName,
      "emergencyPhone": emergencyPhone,
      "emergencyRelation": emergencyRelation,
      "previousAddress": previousAddress,
      "previousLandlordName": previousLandlordName,
      "previousLandlordPhone": previousLandlordPhone,
      "policeVerified": policeVerified,
      "backgroundChecked": backgroundChecked,
      "isActive": isActive,
      "createdAt": createdAt,
    };
  }
}