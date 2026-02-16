import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

class TenantDto {
  final String id;
  final String fullName;
  final String phone;
  final String? alternatePhone;
  final String? email;
  final DateTime? dateOfBirth;
  final String tenantType;
  final String? primaryIdType;
  final String? primaryIdNumber;
  final String? aadhaarNumber;
  final String? panNumber;
  final String? photoUrl;
  final String? idDocumentUrl;
  final String? companyName;
  final String? jobTitle;
  final String? officeAddress;
  final double? monthlyIncome;
  final String propertyId;
  final String roomId;
  final DateTime moveInDate;
  final DateTime? agreementEndDate;
  final int rentAmount;
  final int securityDeposit;
  final String rentFrequency;
  final int rentDueDay;
  final String paymentMode;
  final double lateFinePercentage;
  final int noticePeriodDays;
  final double maintenanceCharge;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelation;
  final String? previousAddress;
  final String? previousLandlordName;
  final String? previousLandlordPhone;
  final bool policeVerified;
  final bool backgroundChecked;
  final bool isActive;
  final DateTime createdAt;

  const TenantDto({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.alternatePhone,
    required this.email,
    required this.dateOfBirth,
    required this.tenantType,
    required this.primaryIdType,
    required this.primaryIdNumber,
    required this.aadhaarNumber,
    required this.panNumber,
    required this.photoUrl,
    required this.idDocumentUrl,
    required this.companyName,
    required this.jobTitle,
    required this.officeAddress,
    required this.monthlyIncome,
    required this.propertyId,
    required this.roomId,
    required this.moveInDate,
    required this.agreementEndDate,
    required this.rentAmount,
    required this.securityDeposit,
    required this.rentFrequency,
    required this.rentDueDay,
    required this.paymentMode,
    required this.lateFinePercentage,
    required this.noticePeriodDays,
    required this.maintenanceCharge,
    required this.emergencyName,
    required this.emergencyPhone,
    required this.emergencyRelation,
    required this.previousAddress,
    required this.previousLandlordName,
    required this.previousLandlordPhone,
    required this.policeVerified,
    required this.backgroundChecked,
    required this.isActive,
    required this.createdAt,
  });

  factory TenantDto.fromEntity(Tenant tenant) {
    return TenantDto(
      id: tenant.id,
      fullName: tenant.fullName,
      phone: tenant.phone,
      alternatePhone: tenant.alternatePhone,
      email: tenant.email,
      dateOfBirth: tenant.dateOfBirth,
      tenantType: tenant.tenantType,
      primaryIdType: tenant.primaryIdType,
      primaryIdNumber: tenant.primaryIdNumber,
      aadhaarNumber: tenant.aadhaarNumber,
      panNumber: tenant.panNumber,
      photoUrl: tenant.photoUrl,
      idDocumentUrl: tenant.idDocumentUrl,
      companyName: tenant.companyName,
      jobTitle: tenant.jobTitle,
      officeAddress: tenant.officeAddress,
      monthlyIncome: tenant.monthlyIncome,
      propertyId: tenant.propertyId,
      roomId: tenant.roomId,
      moveInDate: tenant.moveInDate,
      agreementEndDate: tenant.agreementEndDate,
      rentAmount: tenant.rentAmount,
      securityDeposit: tenant.securityDeposit,
      rentFrequency: tenant.rentFrequency,
      rentDueDay: tenant.rentDueDay,
      paymentMode: tenant.paymentMode,
      lateFinePercentage: tenant.lateFinePercentage,
      noticePeriodDays: tenant.noticePeriodDays,
      maintenanceCharge: tenant.maintenanceCharge,
      emergencyName: tenant.emergencyName,
      emergencyPhone: tenant.emergencyPhone,
      emergencyRelation: tenant.emergencyRelation,
      previousAddress: tenant.previousAddress,
      previousLandlordName: tenant.previousLandlordName,
      previousLandlordPhone: tenant.previousLandlordPhone,
      policeVerified: tenant.policeVerified,
      backgroundChecked: tenant.backgroundChecked,
      isActive: tenant.isActive,
      createdAt: tenant.createdAt,
    );
  }

  factory TenantDto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TenantDto.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});
  }

  factory TenantDto.fromMap(String id, Map<String, dynamic> data) {
    return TenantDto(
      id: id,
      fullName: (data['fullName'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      alternatePhone: data['alternatePhone']?.toString(),
      email: data['email']?.toString(),
      dateOfBirth: _toDateTime(data['dateOfBirth']),
      tenantType: (data['tenantType'] ?? 'Individual').toString(),
      primaryIdType: data['primaryIdType']?.toString(),
      primaryIdNumber: data['primaryIdNumber']?.toString(),
      aadhaarNumber: data['aadhaarNumber']?.toString(),
      panNumber: data['panNumber']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      idDocumentUrl: data['idDocumentUrl']?.toString(),
      companyName: data['companyName']?.toString(),
      jobTitle: data['jobTitle']?.toString(),
      officeAddress: data['officeAddress']?.toString(),
      monthlyIncome: _toDouble(data['monthlyIncome']),
      propertyId: (data['propertyId'] ?? '').toString(),
      roomId: (data['roomId'] ?? '').toString(),
      moveInDate: _toDateTime(data['moveInDate']) ?? DateTime.now(),
      agreementEndDate: _toDateTime(data['agreementEndDate']),
      rentAmount: _toInt(data['rentAmount']),
      securityDeposit: _toInt(data['securityDeposit']),
      rentFrequency: (data['rentFrequency'] ?? 'Monthly').toString(),
      rentDueDay: _toInt(data['rentDueDay'], fallback: 1),
      paymentMode: (data['paymentMode'] ?? 'UPI').toString(),
      lateFinePercentage: _toDouble(data['lateFinePercentage']) ?? 0,
      noticePeriodDays: _toInt(data['noticePeriodDays'], fallback: 30),
      maintenanceCharge: _toDouble(data['maintenanceCharge']) ?? 0,
      emergencyName: data['emergencyName']?.toString(),
      emergencyPhone: data['emergencyPhone']?.toString(),
      emergencyRelation: data['emergencyRelation']?.toString(),
      previousAddress: data['previousAddress']?.toString(),
      previousLandlordName: data['previousLandlordName']?.toString(),
      previousLandlordPhone: data['previousLandlordPhone']?.toString(),
      policeVerified: data['policeVerified'] == true,
      backgroundChecked: data['backgroundChecked'] == true,
      isActive: data['isActive'] != false,
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }

  Tenant toEntity() {
    return Tenant(
      id: id,
      fullName: fullName,
      phone: phone,
      alternatePhone: alternatePhone,
      email: email,
      dateOfBirth: dateOfBirth,
      tenantType: tenantType,
      primaryIdType: primaryIdType,
      primaryIdNumber: primaryIdNumber,
      aadhaarNumber: aadhaarNumber,
      panNumber: panNumber,
      photoUrl: photoUrl,
      idDocumentUrl: idDocumentUrl,
      companyName: companyName,
      jobTitle: jobTitle,
      officeAddress: officeAddress,
      monthlyIncome: monthlyIncome,
      propertyId: propertyId,
      roomId: roomId,
      moveInDate: moveInDate,
      agreementEndDate: agreementEndDate,
      rentAmount: rentAmount,
      securityDeposit: securityDeposit,
      rentFrequency: rentFrequency,
      rentDueDay: rentDueDay,
      paymentMode: paymentMode,
      lateFinePercentage: lateFinePercentage,
      noticePeriodDays: noticePeriodDays,
      maintenanceCharge: maintenanceCharge,
      emergencyName: emergencyName,
      emergencyPhone: emergencyPhone,
      emergencyRelation: emergencyRelation,
      previousAddress: previousAddress,
      previousLandlordName: previousLandlordName,
      previousLandlordPhone: previousLandlordPhone,
      policeVerified: policeVerified,
      backgroundChecked: backgroundChecked,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'alternatePhone': alternatePhone,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'tenantType': tenantType,
      'primaryIdType': primaryIdType,
      'primaryIdNumber': primaryIdNumber,
      'aadhaarNumber': aadhaarNumber,
      'panNumber': panNumber,
      'photoUrl': photoUrl,
      'idDocumentUrl': idDocumentUrl,
      'companyName': companyName,
      'jobTitle': jobTitle,
      'officeAddress': officeAddress,
      'monthlyIncome': monthlyIncome,
      'propertyId': propertyId,
      'roomId': roomId,
      'moveInDate': moveInDate,
      'agreementEndDate': agreementEndDate,
      'rentAmount': rentAmount,
      'securityDeposit': securityDeposit,
      'rentFrequency': rentFrequency,
      'rentDueDay': rentDueDay,
      'paymentMode': paymentMode,
      'lateFinePercentage': lateFinePercentage,
      'noticePeriodDays': noticePeriodDays,
      'maintenanceCharge': maintenanceCharge,
      'emergencyName': emergencyName,
      'emergencyPhone': emergencyPhone,
      'emergencyRelation': emergencyRelation,
      'previousAddress': previousAddress,
      'previousLandlordName': previousLandlordName,
      'previousLandlordPhone': previousLandlordPhone,
      'policeVerified': policeVerified,
      'backgroundChecked': backgroundChecked,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
