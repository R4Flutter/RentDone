import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/core/ads/tenant_ad_subscription_service.dart';

final tenantAdSubscriptionServiceProvider =
    Provider<TenantAdSubscriptionService>(
      (ref) => TenantAdSubscriptionService(),
    );

final tenantAdSubscriptionProvider =
    FutureProvider.autoDispose<TenantAdSubscriptionState>((ref) async {
      return ref.read(tenantAdSubscriptionServiceProvider).getCurrent();
    });
