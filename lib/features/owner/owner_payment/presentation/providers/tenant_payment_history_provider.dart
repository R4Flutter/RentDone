import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/tenant_payment_history_firebase_service.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_property_summary.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_tenant_summary.dart';

final tenantPaymentHistoryServiceProvider =
    Provider<TenantPaymentHistoryFirebaseService>((ref) {
      return TenantPaymentHistoryFirebaseService();
    });

final ownerPaymentPropertiesProvider =
    StreamProvider<List<OwnerPropertySummary>>((ref) {
      // Keep this provider alive across navigation so data isn't re-fetched
      // every time the user switches tabs or navigates back.
      ref.keepAlive();
      final service = ref.watch(tenantPaymentHistoryServiceProvider);
      return service.watchOwnerProperties();
    });

final ownerPropertyTenantsProvider =
    StreamProvider.family<List<OwnerTenantSummary>, String>((ref, propertyId) {
      // Keep alive to avoid re-fetching tenant list on back navigation.
      ref.keepAlive();
      final service = ref.watch(tenantPaymentHistoryServiceProvider);
      return service.watchPropertyTenants(propertyId);
    });
