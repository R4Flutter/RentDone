import 'package:rentdone/features/tenant/data/models/tenant_complaint.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';
import 'package:url_launcher/url_launcher.dart';

mixin TenantDashboardComplaintsMixin {
  TenantFirestoreService get firestoreService;

  Future<void> submitComplaintAndOpenWhatsApp({
    required TenantDashboardSummary summary,
    required TenantComplaint complaint,
  }) async {
    await firestoreService.saveComplaint(
      tenantId: summary.tenantId,
      complaint: complaint,
    );
    var ownerPhone = summary.ownerPhoneNumber.trim();
    if (ownerPhone.isEmpty && summary.tenantId.isNotEmpty) {
      ownerPhone =
          (await firestoreService.getOwnerDetails(
            summary.tenantId,
          ))?.ownerPhoneNumber.trim() ??
          '';
    }
    if (ownerPhone.isEmpty && summary.ownerId.isNotEmpty) {
      ownerPhone = (await firestoreService.getOwnerPhoneNumber(
        summary.ownerId,
      )).trim();
    }
    if (ownerPhone.isEmpty) {
      throw Exception('Owner phone number is not available');
    }

    final message =
        '''Hello Sir,

Complaint from Tenant:
Name: ${summary.tenantName}
Room: ${summary.roomNumber}

Issue Type: ${complaint.category}
Description: ${complaint.description}

Please resolve this issue as soon as possible.''';
    final uri = Uri.parse(
      'https://wa.me/${ownerPhone.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Unable to open WhatsApp');
    }
  }
}
