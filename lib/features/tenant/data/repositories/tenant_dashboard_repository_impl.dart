import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_complaints_mixin.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_details_mixin.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_documents_mixin.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_payments_mixin.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_summary_mixin.dart';
import 'package:rentdone/features/tenant/data/services/firebase_document_storage_service.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';
import 'package:rentdone/features/tenant/domain/repositories/tenant_dashboard_repository.dart';

class TenantDashboardRepositoryImpl
    with
        TenantDashboardSummaryMixin,
        TenantDashboardDetailsMixin,
        TenantDashboardPaymentsMixin,
        TenantDashboardDocumentsMixin,
        TenantDashboardComplaintsMixin
    implements TenantDashboardRepository {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final TenantFirestoreService _firestoreService;
  final FirebaseDocumentStorageService _documentStorageService;

  TenantDashboardRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    TenantFirestoreService? firestoreService,
    FirebaseDocumentStorageService? documentStorageService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _firestoreService = firestoreService ?? TenantFirestoreService(),
       _documentStorageService =
           documentStorageService ?? FirebaseDocumentStorageService();

  @override
  FirebaseAuth get auth => _auth;

  @override
  FirebaseFunctions get functions => _functions;

  @override
  TenantFirestoreService get firestoreService => _firestoreService;

  @override
  FirebaseDocumentStorageService get documentStorageService =>
      _documentStorageService;
}
