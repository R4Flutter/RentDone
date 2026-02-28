import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/features/tenant/data/models/tenant_complaint.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/data/services/cloudinary_document_service.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';
import 'package:rentdone/features/tenant/domain/repositories/tenant_dashboard_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantDashboardRepositoryImpl implements TenantDashboardRepository {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final TenantFirestoreService _firestoreService;
  final CloudinaryDocumentService _cloudinaryService;

  TenantDashboardRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    TenantFirestoreService? firestoreService,
    CloudinaryDocumentService? cloudinaryService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _firestoreService = firestoreService ?? TenantFirestoreService(),
       _cloudinaryService = cloudinaryService ?? CloudinaryDocumentService();

  @override
  Future<TenantDashboardSummary> getDashboardSummary() async {
    final user = _auth.currentUser;
    if (user == null) {
      return TenantDashboardSummary.empty;
    }

    final authEmail = (user.email ?? '').trim();
    if (authEmail.isNotEmpty) {
      try {
        await _firestoreService.ensureTenantUserDoc(
          uid: user.uid,
          email: authEmail,
        );
      } on FirebaseException {
        // Continue with current state if rules temporarily reject this write.
      }
    }

    try {
      final summary = await _firestoreService.getDashboardSummary(
        uid: user.uid,
        email: user.email,
      );

      final resolvedSummary = await _resolveSummaryWithAutoLink(
        user: user,
        initialSummary: summary,
      );

      final effectiveEmail = (user.email ?? '').trim().isNotEmpty
          ? user.email!
          : resolvedSummary.tenantEmail;

      return TenantDashboardSummary(
        tenantId: resolvedSummary.tenantId,
        tenantName: resolvedSummary.tenantName,
        tenantEmail: effectiveEmail,
        tenantPhone: _resolveTenantPhone(
          summaryPhone: resolvedSummary.tenantPhone,
          authPhone: user.phoneNumber,
        ),
        ownerId: resolvedSummary.ownerId,
        roomNumber: resolvedSummary.roomNumber,
        propertyName: resolvedSummary.propertyName,
        monthlyRent: resolvedSummary.monthlyRent,
        depositAmount: resolvedSummary.depositAmount,
        allocationDate: resolvedSummary.allocationDate,
        rentDueDay: resolvedSummary.rentDueDay,
        ownerPhoneNumber: resolvedSummary.ownerPhoneNumber,
        dueAmount: resolvedSummary.dueAmount,
        lifetimePaid: resolvedSummary.lifetimePaid,
        currentMonthName: resolvedSummary.currentMonthName,
        profileImageUrl: user.photoURL ?? resolvedSummary.profileImageUrl,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return TenantDashboardSummary(
          tenantId: '',
          tenantName: user.displayName ?? 'Tenant',
          tenantEmail: user.email ?? '',
          tenantPhone: user.phoneNumber ?? '',
          ownerId: '',
          roomNumber: '-',
          propertyName: '',
          monthlyRent: 0,
          depositAmount: null,
          allocationDate: null,
          rentDueDay: 1,
          ownerPhoneNumber: '',
          dueAmount: 0,
          lifetimePaid: 0,
          currentMonthName: '',
          profileImageUrl: user.photoURL,
        );
      }
      rethrow;
    }
  }

  String _resolveTenantPhone({String? summaryPhone, String? authPhone}) {
    final normalizedSummary = (summaryPhone ?? '').trim();
    if (normalizedSummary.isNotEmpty) {
      return normalizedSummary;
    }

    final normalizedAuthPhone = (authPhone ?? '').trim();
    if (normalizedAuthPhone.isNotEmpty) {
      return normalizedAuthPhone;
    }

    return '';
  }

  Future<TenantDashboardSummary> _resolveSummaryWithAutoLink({
    required User user,
    required TenantDashboardSummary initialSummary,
  }) async {
    if (initialSummary.tenantId.isNotEmpty) {
      return initialSummary;
    }

    var resolvedSummary = initialSummary;
    const retryDelays = <Duration>[
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1500),
    ];

    for (var index = 0; index < retryDelays.length; index++) {
      await _tryLinkTenantAccount();
      resolvedSummary = await _firestoreService.getDashboardSummary(
        uid: user.uid,
        email: user.email,
      );

      if (resolvedSummary.tenantId.isNotEmpty) {
        return resolvedSummary;
      }

      await Future<void>.delayed(retryDelays[index]);
    }

    if (resolvedSummary.tenantId.isEmpty &&
        (user.email ?? '').trim().isNotEmpty) {
      try {
        await _firestoreService.ensureSelfTenantProfile(
          uid: user.uid,
          email: user.email!.trim(),
          displayName: user.displayName,
          phoneNumber: user.phoneNumber,
        );

        resolvedSummary = await _firestoreService.getDashboardSummary(
          uid: user.uid,
          email: user.email,
        );
      } on FirebaseException {
        // Keep graceful fallback to empty summary when rules are not deployed yet.
      }
    }

    return resolvedSummary;
  }

  Future<void> _tryLinkTenantAccount() async {
    try {
      await _functions.httpsCallable('linkTenantAccount').call();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied' ||
          e.code == 'unauthenticated' ||
          e.code == 'failed-precondition') {
        rethrow;
      }
    } catch (_) {
      // Silent fallback to existing behavior when backend is not deployed yet.
    }
  }

  @override
  Stream<TenantPayment?> watchCurrentMonthPayment(String tenantId) {
    return _firestoreService.watchCurrentMonthPayment(tenantId);
  }

  @override
  Future<TenantRoomDetails?> getRoomDetails(String tenantId) {
    return _firestoreService.getRoomDetails(tenantId);
  }

  @override
  Future<void> saveRoomDetails({
    required String tenantId,
    required TenantRoomDetails details,
  }) {
    return _firestoreService.saveRoomDetails(
      tenantId: tenantId,
      details: details,
    );
  }

  @override
  Future<TenantOwnerDetails?> getOwnerDetails(String tenantId) {
    return _firestoreService.getOwnerDetails(tenantId);
  }

  @override
  Future<void> saveOwnerDetails({
    required String tenantId,
    required TenantOwnerDetails details,
  }) {
    return _firestoreService.saveOwnerDetails(
      tenantId: tenantId,
      details: details,
    );
  }

  @override
  Future<void> saveTenantBasicDetails({
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
  }) {
    return _firestoreService.saveTenantBasicDetails(
      tenantId: tenantId,
      tenantName: tenantName,
      tenantEmail: tenantEmail,
      tenantPhone: tenantPhone,
    );
  }

  @override
  Future<void> markPaymentAsPaid({
    required String tenantId,
    required int amountPaid,
    required DateTime paymentDate,
    required String paymentMethod,
    required int monthlyRent,
  }) {
    return _firestoreService.markPaymentAsPaid(
      tenantId: tenantId,
      amountPaid: amountPaid,
      paymentDate: paymentDate,
      paymentMethod: paymentMethod,
      monthlyRent: monthlyRent,
    );
  }

  @override
  Future<List<TenantReminder>> getRecentReminders(
    String tenantId, {
    int limit = 5,
  }) {
    return _firestoreService.getRecentReminders(tenantId, limit: limit);
  }

  @override
  Future<List<TenantDocument>> getDocumentsPage(
    String tenantId, {
    String? lastDocumentId,
    int limit = 20,
  }) {
    return _firestoreService.getDocumentsPage(
      tenantId,
      lastDocumentId: lastDocumentId,
      limit: limit,
    );
  }

  @override
  Future<TenantDocument> uploadDocument({
    required String tenantId,
    required File file,
    required String fileName,
    required String description,
    required int fileSizeBytes,
  }) async {
    final uploadResult = await _cloudinaryService.uploadTenantDocument(
      tenantId: tenantId,
      file: file,
      fileName: fileName,
    );

    final fileType = _resolveFileType(fileName);

    try {
      await _firestoreService.saveUploadedDocument(
        tenantId: tenantId,
        fileUrl: uploadResult.secureUrl,
        fileType: fileType,
        publicId: uploadResult.publicId,
        description: description,
        fileSizeBytes: fileSizeBytes,
        deleteToken: uploadResult.deleteToken,
      );
    } catch (error) {
      final deleteToken = uploadResult.deleteToken;
      if (deleteToken != null && deleteToken.isNotEmpty) {
        try {
          await _cloudinaryService.deleteWithToken(deleteToken);
        } catch (_) {
          // Ignore rollback failures to preserve the primary upload error.
        }
      }
      rethrow;
    }

    return TenantDocument(
      id: '',
      fileUrl: uploadResult.secureUrl,
      fileType: fileType,
      uploadedAt: uploadResult.createdAt,
      description: description,
      publicId: uploadResult.publicId,
      fileSizeBytes: fileSizeBytes,
      deleteToken: uploadResult.deleteToken,
    );
  }

  @override
  Future<void> deleteDocument({
    required String tenantId,
    required TenantDocument document,
  }) async {
    if (document.deleteToken == null || document.deleteToken!.isEmpty) {
      throw Exception(
        'Delete token missing. Upload should be deleted by backend Cloudinary signature flow.',
      );
    }

    await _cloudinaryService.deleteWithToken(document.deleteToken!);
    await _firestoreService.deleteDocument(tenantId, document.id);
  }

  @override
  Future<void> submitComplaintAndOpenWhatsApp({
    required TenantDashboardSummary summary,
    required TenantComplaint complaint,
  }) async {
    await _firestoreService.saveComplaint(
      tenantId: summary.tenantId,
      complaint: complaint,
    );

    String ownerPhone = summary.ownerPhoneNumber.trim();

    if (ownerPhone.isEmpty && summary.tenantId.isNotEmpty) {
      final ownerDetails = await _firestoreService.getOwnerDetails(
        summary.tenantId,
      );
      ownerPhone = ownerDetails?.ownerPhoneNumber.trim() ?? '';
    }

    if (ownerPhone.isEmpty && summary.ownerId.isNotEmpty) {
      ownerPhone = (await _firestoreService.getOwnerPhoneNumber(
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

    final phone = ownerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw Exception('Unable to open WhatsApp');
    }
  }

  String _resolveFileType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return 'image';
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi')) {
      return 'video';
    }
    return 'other';
  }
}
