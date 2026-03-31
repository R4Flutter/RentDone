import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';

class TenantDashboardAutoLinkHelper {
  final FirebaseFunctions functions;
  final TenantFirestoreService firestoreService;

  const TenantDashboardAutoLinkHelper({
    required this.functions,
    required this.firestoreService,
  });

  Future<TenantDashboardSummary> resolve(
    User user,
    TenantDashboardSummary initialSummary,
  ) async {
    if (initialSummary.tenantId.isNotEmpty) return initialSummary;
    var resolved = initialSummary;
    for (final delay in const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
      Duration(milliseconds: 1500),
    ]) {
      await _tryLinkTenantAccount();
      resolved = await firestoreService.getDashboardSummary(
        uid: user.uid,
        email: user.email,
      );
      if (resolved.tenantId.isNotEmpty) return resolved;
      await Future<void>.delayed(delay);
    }
    if (resolved.tenantId.isEmpty && (user.email ?? '').trim().isNotEmpty) {
      try {
        await firestoreService.ensureSelfTenantProfile(
          uid: user.uid,
          email: user.email!.trim(),
          displayName: user.displayName,
          phoneNumber: user.phoneNumber,
        );
        return await firestoreService.getDashboardSummary(
          uid: user.uid,
          email: user.email,
        );
      } catch (_) {
        // Ignore bootstrap failures and fall back to the unresolved summary.
      }
    }
    return resolved;
  }

  Future<void> _tryLinkTenantAccount() async {
    try {
      await functions.httpsCallable('linkTenantAccount').call();
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated' ||
          error.code == 'failed-precondition') {
        rethrow;
      }
    } catch (_) {
      // Network and transient callable failures should not block summary reads.
    }
  }
}
