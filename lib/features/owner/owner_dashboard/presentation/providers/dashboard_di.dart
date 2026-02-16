import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/repositories/session_repository_impl.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/services/dashboard_firebase_service.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/services/session_auth_service.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/session_repository.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/usecases/get_dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/usecases/logout_owner.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/usecases/refresh_dashboard.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/usecases/watch_recent_messages.dart';

final dashboardFirebaseServiceProvider = Provider<DashboardFirebaseService>((
  ref,
) {
  return DashboardFirebaseService();
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final service = ref.watch(dashboardFirebaseServiceProvider);
  return DashboardRepositoryImpl(service);
});

final getDashboardSummaryUseCaseProvider = Provider<GetDashboardSummary>((ref) {
  return GetDashboardSummary(ref.watch(dashboardRepositoryProvider));
});

final refreshDashboardUseCaseProvider = Provider<RefreshDashboard>((ref) {
  return RefreshDashboard(ref.watch(dashboardRepositoryProvider));
});

final watchRecentMessagesUseCaseProvider = Provider<WatchRecentMessages>((ref) {
  return WatchRecentMessages(ref.watch(dashboardRepositoryProvider));
});

final sessionAuthServiceProvider = Provider<SessionAuthService>((ref) {
  return SessionAuthService();
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final service = ref.watch(sessionAuthServiceProvider);
  return SessionRepositoryImpl(service);
});

final logoutOwnerUseCaseProvider = Provider<LogoutOwner>((ref) {
  return LogoutOwner(ref.watch(sessionRepositoryProvider));
});
