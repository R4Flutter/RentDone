import 'dart:io';

import 'package:rentdone/features/tenant/data/models/tenant_complaint.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

abstract class TenantDashboardRepository {
  Future<TenantDashboardSummary> getDashboardSummary();

  Stream<TenantPayment?> watchCurrentMonthPayment(String tenantId);

  Future<TenantRoomDetails?> getRoomDetails(String tenantId);

  Future<void> saveRoomDetails({
    required String tenantId,
    required TenantRoomDetails details,
  });

  Future<TenantOwnerDetails?> getOwnerDetails(String tenantId);

  Future<void> saveOwnerDetails({
    required String tenantId,
    required TenantOwnerDetails details,
  });

  Future<void> saveTenantBasicDetails({
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
  });

  Future<void> markPaymentAsPaid({
    required String tenantId,
    required int amountPaid,
    required DateTime paymentDate,
    required String paymentMethod,
    required int monthlyRent,
  });

  Future<List<TenantReminder>> getRecentReminders(
    String tenantId, {
    int limit = 5,
  });

  Future<List<TenantDocument>> getDocumentsPage(
    String tenantId, {
    String? lastDocumentId,
    int limit = 20,
  });

  Future<TenantDocument> uploadDocument({
    required String tenantId,
    required File file,
    required String fileName,
    required String description,
    required int fileSizeBytes,
  });

  Future<void> deleteDocument({
    required String tenantId,
    required TenantDocument document,
  });

  Future<void> submitComplaintAndOpenWhatsApp({
    required TenantDashboardSummary summary,
    required TenantComplaint complaint,
  });
}
