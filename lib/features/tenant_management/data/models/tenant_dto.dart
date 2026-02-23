import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/tenant_entity.dart';

/// Data Transfer Object for Tenant
/// Handles serialization/deserialization with Firestore
class TenantDTO {
  final String id;
  final String ownerId;
  final String propertyId;
  final String fullName;
  final String phone;
  final String? email;
  final String? profileImageUrl;
  final DateTime? dateOfBirth;
  final String roomNumber;
  final int rentAmount;
  final int securityDeposit;
  final DateTime leaseStartDate;
  final DateTime? leaseEndDate;
  final int rentDueDate;
  final String rentFrequency;
  final String paymentMode;
  final String? upiId;
  final double lateFinePercentage;
  final double maintenanceCharge;
  final int noticePeriodDays;
  final String? idProofType;
  final String? idProofUrl;
  final String? agreementUrl;
  final List<String> additionalDocumentUrls;
  final String? companyName;
  final String? jobTitle;
  final double? monthlyIncome;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelation;
  final String? previousLandlordName;
  final String? previousLandlordPhone;
  final String? previousAddress;
  final bool policeVerified;
  final bool backgroundChecked;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TenantDTO({
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

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'propertyId': propertyId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'dateOfBirth': dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      'roomNumber': roomNumber,
      'rentAmount': rentAmount,
      'securityDeposit': securityDeposit,
      'leaseStartDate': Timestamp.fromDate(leaseStartDate),
      'leaseEndDate': leaseEndDate != null
          ? Timestamp.fromDate(leaseEndDate!)
          : null,
      'rentDueDate': rentDueDate,
      'rentFrequency': rentFrequency,
      'paymentMode': paymentMode,
      'upiId': upiId,
      'lateFinePercentage': lateFinePercentage,
      'maintenanceCharge': maintenanceCharge,
      'noticePeriodDays': noticePeriodDays,
      'idProofType': idProofType,
      'idProofUrl': idProofUrl,
      'agreementUrl': agreementUrl,
      'additionalDocumentUrls': additionalDocumentUrls,
      'companyName': companyName,
      'jobTitle': jobTitle,
      'monthlyIncome': monthlyIncome,
      'emergencyName': emergencyName,
      'emergencyPhone': emergencyPhone,
      'emergencyRelation': emergencyRelation,
      'previousLandlordName': previousLandlordName,
      'previousLandlordPhone': previousLandlordPhone,
      'previousAddress': previousAddress,
      'policeVerified': policeVerified,
      'backgroundChecked': backgroundChecked,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory TenantDTO.fromMap(Map<String, dynamic> map) {
    return TenantDTO(
      id: map['id'] as String,
      ownerId: map['ownerId'] as String,
      propertyId: map['propertyId'] as String,
      fullName: map['fullName'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      dateOfBirth: map['dateOfBirth'] != null
          ? (map['dateOfBirth'] as Timestamp).toDate()
          : null,
      roomNumber: map['roomNumber'] as String,
      rentAmount: map['rentAmount'] as int,
      securityDeposit: map['securityDeposit'] as int,
      leaseStartDate: (map['leaseStartDate'] as Timestamp).toDate(),
      leaseEndDate: map['leaseEndDate'] != null
          ? (map['leaseEndDate'] as Timestamp).toDate()
          : null,
      rentDueDate: map['rentDueDate'] as int,
      rentFrequency: map['rentFrequency'] as String,
      paymentMode: map['paymentMode'] as String,
      upiId: map['upiId'] as String?,
      lateFinePercentage: (map['lateFinePercentage'] as num).toDouble(),
      maintenanceCharge: (map['maintenanceCharge'] as num).toDouble(),
      noticePeriodDays: map['noticePeriodDays'] as int,
      idProofType: map['idProofType'] as String?,
      idProofUrl: map['idProofUrl'] as String?,
      agreementUrl: map['agreementUrl'] as String?,
      additionalDocumentUrls: List<String>.from(
        map['additionalDocumentUrls'] as List? ?? [],
      ),
      companyName: map['companyName'] as String?,
      jobTitle: map['jobTitle'] as String?,
      monthlyIncome: map['monthlyIncome'] as double?,
      emergencyName: map['emergencyName'] as String?,
      emergencyPhone: map['emergencyPhone'] as String?,
      emergencyRelation: map['emergencyRelation'] as String?,
      previousLandlordName: map['previousLandlordName'] as String?,
      previousLandlordPhone: map['previousLandlordPhone'] as String?,
      previousAddress: map['previousAddress'] as String?,
      policeVerified: map['policeVerified'] as bool? ?? false,
      backgroundChecked: map['backgroundChecked'] as bool? ?? false,
      status: map['status'] as String? ?? 'active',
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert DTO to Entity
  TenantEntity toEntity() {
    return TenantEntity(
      id: id,
      ownerId: ownerId,
      propertyId: propertyId,
      fullName: fullName,
      phone: phone,
      email: email,
      profileImageUrl: profileImageUrl,
      dateOfBirth: dateOfBirth,
      roomNumber: roomNumber,
      rentAmount: rentAmount,
      securityDeposit: securityDeposit,
      leaseStartDate: leaseStartDate,
      leaseEndDate: leaseEndDate,
      rentDueDate: rentDueDate,
      rentFrequency: rentFrequency,
      paymentMode: paymentMode,
      upiId: upiId,
      lateFinePercentage: lateFinePercentage,
      maintenanceCharge: maintenanceCharge,
      noticePeriodDays: noticePeriodDays,
      idProofType: idProofType,
      idProofUrl: idProofUrl,
      agreementUrl: agreementUrl,
      additionalDocumentUrls: additionalDocumentUrls,
      companyName: companyName,
      jobTitle: jobTitle,
      monthlyIncome: monthlyIncome,
      emergencyName: emergencyName,
      emergencyPhone: emergencyPhone,
      emergencyRelation: emergencyRelation,
      previousLandlordName: previousLandlordName,
      previousLandlordPhone: previousLandlordPhone,
      previousAddress: previousAddress,
      policeVerified: policeVerified,
      backgroundChecked: backgroundChecked,
      createdAt: createdAt,
      status: status,
      notes: notes,
      updatedAt: updatedAt,
    );
  }

  /// Create DTO from Entity
  factory TenantDTO.fromEntity(TenantEntity entity) {
    return TenantDTO(
      id: entity.id,
      ownerId: entity.ownerId,
      propertyId: entity.propertyId,
      fullName: entity.fullName,
      phone: entity.phone,
      email: entity.email,
      profileImageUrl: entity.profileImageUrl,
      dateOfBirth: entity.dateOfBirth,
      roomNumber: entity.roomNumber,
      rentAmount: entity.rentAmount,
      securityDeposit: entity.securityDeposit,
      leaseStartDate: entity.leaseStartDate,
      leaseEndDate: entity.leaseEndDate,
      rentDueDate: entity.rentDueDate,
      rentFrequency: entity.rentFrequency,
      paymentMode: entity.paymentMode,
      upiId: entity.upiId,
      lateFinePercentage: entity.lateFinePercentage,
      maintenanceCharge: entity.maintenanceCharge,
      noticePeriodDays: entity.noticePeriodDays,
      idProofType: entity.idProofType,
      idProofUrl: entity.idProofUrl,
      agreementUrl: entity.agreementUrl,
      additionalDocumentUrls: entity.additionalDocumentUrls,
      companyName: entity.companyName,
      jobTitle: entity.jobTitle,
      monthlyIncome: entity.monthlyIncome,
      emergencyName: entity.emergencyName,
      emergencyPhone: entity.emergencyPhone,
      emergencyRelation: entity.emergencyRelation,
      previousLandlordName: entity.previousLandlordName,
      previousLandlordPhone: entity.previousLandlordPhone,
      previousAddress: entity.previousAddress,
      policeVerified: entity.policeVerified,
      backgroundChecked: entity.backgroundChecked,
      createdAt: entity.createdAt,
      status: entity.status,
      notes: entity.notes,
      updatedAt: entity.updatedAt,
    );
  }
}
