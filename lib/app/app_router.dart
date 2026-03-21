import 'package:rentdone/app/app_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

import 'package:rentdone/features/auth/presentation/pages/login_screen.dart';
import 'package:rentdone/features/auth/presentation/pages/phone_capture_screen.dart';
import 'package:rentdone/features/auth/presentation/pages/signup_screen.dart';
import 'package:rentdone/features/owner/add_tenant/presentation/pages/owner_add_property.dart'
    as owner_add_tenant;
import 'package:rentdone/features/owner/owner_dashboard/presentation/pages/dashboard/dashboard_screen.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/pages/dashboard/owner_dashboard.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/pages/payment_failure_screen.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/pages/payment_screen.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/pages/payment_success_screen.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/pages/tenant_list_screen.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/pages/tenant_payment_history_screen.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/pages/profile_screen.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/pages/owner_bank_details_screen.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/pages/owner_settings_screen.dart';
import 'package:rentdone/features/owner/owner_subscription/presentation/pages/owner_subscription_screen.dart';
import 'package:rentdone/features/owner/owner_support/presentation/pages/support_screen.dart';
import 'package:rentdone/features/owner/owner_notifications/presentation/pages/owner_notifications_screen.dart';
import 'package:rentdone/features/owner/owner_tenants/presentation/pages/manage_tenants_screen.dart';
import 'package:rentdone/features/owner/owner_tenants/presentation/pages/tenant_trust_search_screen.dart';
import 'package:rentdone/features/owner/owner_tenants/presentation/pages/tenant_trust_score_screen.dart';
import 'package:rentdone/features/owner/owners_properties/presentation/pages/manage_property_screen.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/pages/add_property_screen.dart';
import 'package:rentdone/features/owner/reports/presentation/pages/report_screen.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/presentation/screens/transaction_history_screen.dart';
import 'package:rentdone/features/tenant/presentation/pages/tenant_dashboard_screen.dart';
import 'package:rentdone/features/tenant/presentation/pages/tenant_documents_screen.dart';
import 'package:rentdone/features/tenant/presentation/pages/tenant_dashboard_shell.dart';
import 'package:rentdone/features/tenant/presentation/pages/tenant_complaint_screen.dart';
import 'package:rentdone/features/tenant/presentation/pages/tenant_profile_screen.dart';
import 'package:rentdone/features/tenant/presentation/pages/tenant_tenancy_details_screen.dart';
import 'package:rentdone/features/tenant_management/presentation/pages/add_tenant_screen.dart';
import 'package:rentdone/features/tenant_management/presentation/pages/edit_tenant_screen.dart';
import 'package:rentdone/features/tenant_management/presentation/pages/record_payment_screen.dart';
import 'package:rentdone/features/tenant_management/presentation/pages/tenant_list_screen.dart';
import 'package:rentdone/features/tenant_management/presentation/pages/tenant_analytics_screen.dart';
import 'package:rentdone/shared/widgets/back_handler.dart';
import 'package:rentdone/shared/pages/role_selection_screen.dart';
import 'package:rentdone/shared/pages/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  var hasHandledInitialRouteGuard = false;

  return GoRouter(
    initialLocation: '/',
    overridePlatformDefaultLocation: true,
    refreshListenable: _RouterRefreshNotifier(firebaseAuth.authStateChanges()),
    redirect: (context, state) async {
      final isLoggedIn = firebaseAuth.currentUser != null;
      final path = state.uri.path;
      bool isValidPhone(String? value) {
        final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
        return RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
      }

      if (!hasHandledInitialRouteGuard) {
        hasHandledInitialRouteGuard = true;
        final isProtectedRoute =
            path.startsWith('/owner') || path.startsWith('/tenant');
        if (isProtectedRoute && path != '/') {
          return '/';
        }
      }

      // Allow access to role selection and login for unauthenticated users
      if (!isLoggedIn) {
        final requiresAuth =
            path.startsWith('/owner') || path.startsWith('/tenant');
        if (requiresAuth) {
          if (path.startsWith('/tenant')) {
            return '/phone?role=tenant';
          }
          return '/phone?role=owner';
        }

        if (path == '/login') {
          final roleParam = state.uri.queryParameters['role'];
          final selectedRole = UserRoleX.tryParse(roleParam) ?? UserRole.owner;
          final phone = state.uri.queryParameters['phone'];
          if (!isValidPhone(phone)) {
            return '/phone?role=${selectedRole.name}';
          }
        }

        if (path == '/signup') {
          final roleParam = state.uri.queryParameters['role'];
          final selectedRole = UserRoleX.tryParse(roleParam) ?? UserRole.owner;
          final phone = state.uri.queryParameters['phone'];
          if (!isValidPhone(phone)) {
            return '/phone?role=${selectedRole.name}';
          }
        }

        return null; // Allow /role, /phone, /login and /signup
      }

      // User is authenticated - check their role
      final uid = firebaseAuth.currentUser!.uid;
      final role = await ref.read(authRepositoryProvider).getUserRole(uid);

      // If user has no role yet, only allow /role and /login
      if (role == null) {
        if (path == '/role' ||
            path == '/phone' ||
            path == '/login' ||
            path == '/signup') {
          return null; // Allow these paths
        }
        return '/role'; // Redirect everything else to role selection
      }

      if (role == UserRole.owner && path.startsWith('/tenant')) {
        return '/owner/dashboard';
      }

      if (role == UserRole.tenant && path.startsWith('/owner')) {
        return '/tenant/dashboard';
      }

      // If user with role tries to access role selection or login, redirect to their dashboard
      if (path == '/role' ||
          path == '/phone' ||
          path == '/login' ||
          path == '/signup' ||
          path == '/') {
        // Check whether the user's profile is complete (name + phone required)
        try {
          final userDoc = await ref
              .read(firestoreProvider)
              .collection('users')
              .doc(uid)
              .get();
          final data = userDoc.data() ?? {};
          final phone = (data['phone'] as String? ?? '').trim();
          final name = (data['name'] as String? ?? '').trim();
          if (phone.isEmpty || name.isEmpty) {
            return role == UserRole.owner
                ? '/owner/profile?setup=true'
                : '/tenant/profile?setup=true';
          }
        } catch (_) {
          // If Firestore check fails, fall through to dashboard normally
        }
        return role == UserRole.owner
            ? '/owner/dashboard'
            : '/tenant/dashboard';
      }

      return null;
    },
    routes: [
      // ============================================================
      // 🌍 AUTHENTICATION & ONBOARDING ROUTES
      // ============================================================

      /// 🌊 Splash Screen - App Entry Point
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const BackHandler.root(
          dialogTitle: 'Exit RentDone?',
          dialogMessage: 'Are you sure you want to exit?',
          child: SplashPage(),
        ),
      ),

      /// 🎭 Role Selection Screen
      GoRoute(
        path: '/role',
        name: 'roleSelection',
        builder: (context, state) => const BackHandler.root(
          dialogTitle: 'Exit RentDone?',
          dialogMessage: 'Are you sure you want to exit?',
          child: RoleSelectionScreen(),
        ),
      ),

      /// 🔐 Login Screen
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) {
          final roleParam = state.uri.queryParameters['role'];
          final phone = state.uri.queryParameters['phone'] ?? '';
          final selectedRole = UserRoleX.tryParse(roleParam) ?? UserRole.owner;
          return BackHandler.root(
            dialogTitle: 'Exit RentDone?',
            dialogMessage: 'Are you sure you want to exit?',
            child: LoginPage(selectedRole: selectedRole, phoneNumber: phone),
          );
        },
      ),

      /// 📱 Phone Verification Before Login
      GoRoute(
        path: '/phone',
        name: 'phoneCapture',
        builder: (context, state) {
          final roleParam = state.uri.queryParameters['role'];
          final selectedRole = UserRoleX.tryParse(roleParam) ?? UserRole.owner;
          return BackHandler.root(
            dialogTitle: 'Exit RentDone?',
            dialogMessage: 'Are you sure you want to exit?',
            child: PhoneCapturePage(selectedRole: selectedRole),
          );
        },
      ),

      /// 🆕 Signup Screen
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) {
          final roleParam = state.uri.queryParameters['role'];
          final phone = state.uri.queryParameters['phone'] ?? '';
          final selectedRole = UserRoleX.tryParse(roleParam) ?? UserRole.owner;
          return BackHandler.root(
            dialogTitle: 'Exit RentDone?',
            dialogMessage: 'Are you sure you want to exit?',
            child: SignupPage(selectedRole: selectedRole, phoneNumber: phone),
          );
        },
      ),

      // ============================================================
      // 🧑‍💼 TENANT ROUTES
      // ============================================================
      ShellRoute(
        builder: (context, state, child) => TenantDashboardShell(child: child),
        routes: [
          GoRoute(
            path: '/tenant/dashboard',
            name: 'tenantDashboard',
            builder: (context, state) => const TenantDashboardScreen(),
          ),
          GoRoute(
            path: '/tenant/documents',
            name: 'tenantDocuments',
            builder: (context, state) => const TenantDocumentsScreen(),
          ),
          GoRoute(
            path: '/tenant/complaints',
            name: 'tenantComplaints',
            builder: (context, state) => const TenantComplaintScreen(),
          ),
          GoRoute(
            path: '/tenant/profile',
            name: 'tenantProfile',
            builder: (context, state) {
              final setup = state.uri.queryParameters['setup'] == 'true';
              return TenantProfileScreen(isSetupMode: setup);
            },
          ),
          GoRoute(
            path: '/tenant/transactions',
            name: 'tenantTransactions',
            builder: (context, state) =>
                const TransactionHistoryScreen(actor: TransactionActor.tenant),
          ),
          GoRoute(
            path: '/tenant/tenancy-details',
            name: 'tenantTenancyDetails',
            builder: (context, state) => const TenantTenancyDetailsScreen(),
          ),
        ],
      ),

      // ============================================================
      // 🏠 OWNER DASHBOARD SHELL & ROUTES
      // ============================================================

      /// Main Shell Route - Owner Dashboard Layout
      ShellRoute(
        builder: (context, state, child) {
          return OwnerDashboardPage(child: child);
        },
        routes: [
          // ========================================================
          // 📊 DASHBOARD
          // ========================================================

          /// 📊 Main Dashboard
          GoRoute(
            path: '/owner/dashboard',
            name: 'ownerDashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          // ========================================================
          // 🏠 PROPERTY MANAGEMENT
          // ========================================================

          /// �️ Manage Properties - CRUD Operations
          GoRoute(
            path: '/owner/properties/manage',
            name: 'manageProperties',
            builder: (context, state) => const ManagePropertiesScreen(),
          ),

          /// ➕ Add New Property
          GoRoute(
            path: '/owner/properties/add',
            name: 'addProperty',
            builder: (context, state) => const AddPropertyScreen(),
          ),

          /// ✏️ Edit Existing Property
          GoRoute(
            path: '/owner/properties/edit/:propertyId',
            name: 'editProperty',
            builder: (context, state) {
              // final propertyId = state.pathParameters['propertyId'];
              // You can pass the property object if needed
              return const AddPropertyScreen();
            },
          ),

          /// 🏠 Property Overview - View All Properties & Tenants
          GoRoute(
            path: '/owner/properties',
            name: 'ownerProperties',
            builder: (context, state) => const ManagePropertiesScreen(),
          ),

          // ========================================================
          // 👥 TENANT MANAGEMENT
          // ========================================================

          /// ➕ Add New Tenant to Property
          GoRoute(
            path: '/owner/tenants/add',
            name: 'addTenant',
            builder: (context, state) {
              final propertyId = state.uri.queryParameters['propertyId'];
              final roomId = state.uri.queryParameters['roomId'];
              return owner_add_tenant.AddTenantScreen(
                propertyId: propertyId,
                roomId: roomId,
              );
            },
          ),

          /// 👥 Manage Tenants
          GoRoute(
            path: '/owner/tenants/manage',
            name: 'manageTenants',
            builder: (context, state) => const ManageTenantsScreen(),
          ),

          /// 🔎 Tenant Trust Search
          GoRoute(
            path: '/owner/tenants/trust-search',
            name: 'tenantTrustSearch',
            builder: (context, state) => const TenantTrustSearchScreen(),
          ),

          /// ✏️ Edit Tenant Information
          GoRoute(
            path: '/owner/tenants/edit/:tenantId',
            name: 'editTenant',
            builder: (context, state) {
              final tenantId = state.pathParameters['tenantId'] ?? '';
              return EditTenantScreen(tenantId: tenantId);
            },
          ),

          /// 📋 Tenant Management Routes (SaaS-Ready)
          GoRoute(
            path: '/tenant-management/list',
            name: 'tenantList',
            builder: (context, state) => const TenantListScreen(),
          ),

          GoRoute(
            path: '/tenant-management/add-tenant',
            name: 'addTenantManagement',
            builder: (context, state) {
              final propertyId = state.uri.queryParameters['propertyId'] ?? '';
              return AddTenantScreen(propertyId: propertyId);
            },
          ),

          GoRoute(
            path: '/tenant-management/edit-tenant/:tenantId',
            name: 'editTenantManagement',
            builder: (context, state) {
              final tenantId = state.pathParameters['tenantId'] ?? '';
              return EditTenantScreen(tenantId: tenantId);
            },
          ),

          GoRoute(
            path: '/tenant-management/record-payment/:tenantId',
            name: 'recordPayment',
            builder: (context, state) {
              final tenantId = state.pathParameters['tenantId'] ?? '';
              final propertyId = state.uri.queryParameters['propertyId'] ?? '';
              return RecordPaymentScreen(
                tenantId: tenantId,
                propertyId: propertyId,
              );
            },
          ),

          GoRoute(
            path: '/tenant-management/analytics',
            name: 'tenantAnalytics',
            builder: (context, state) => const TenantAnalyticsScreen(),
          ),

          // ========================================================
          // 💰 PAYMENTS & FINANCIAL
          // ========================================================

          /// 💰 Payment Management - View & Track Payments
          GoRoute(
            path: '/owner/payments',
            name: 'ownerPayments',
            builder: (context, state) => PaymentsScreen(
              initialStatus: state.uri.queryParameters['status'],
              initialTenantId: state.uri.queryParameters['tenantId'],
              initialPropertyId: state.uri.queryParameters['propertyId'],
              initialTenantName: state.uri.queryParameters['tenantName'],
            ),
          ),

          GoRoute(
            path: '/owner/payments/property/:propertyId',
            name: 'ownerPaymentTenants',
            builder: (context, state) {
              final propertyId = state.pathParameters['propertyId'] ?? '';
              return OwnerPaymentTenantListScreen(
                propertyId: propertyId,
                propertyName: state.uri.queryParameters['propertyName'],
              );
            },
          ),

          GoRoute(
            path: '/owner/payments/property/:propertyId/tenant/:tenantId',
            name: 'ownerTenantPaymentHistory',
            builder: (context, state) {
              final propertyId = state.pathParameters['propertyId'] ?? '';
              final tenantId = state.pathParameters['tenantId'] ?? '';
              final rentAmount = int.tryParse(
                state.uri.queryParameters['rentAmount'] ?? '',
              );

              return TenantPaymentHistoryScreen(
                propertyId: propertyId,
                tenantId: tenantId,
                propertyName: state.uri.queryParameters['propertyName'],
                tenantName: state.uri.queryParameters['tenantName'],
                roomNumber: state.uri.queryParameters['roomNumber'],
                rentAmount: rentAmount,
                phone: state.uri.queryParameters['phone'],
              );
            },
          ),

          GoRoute(
            path: '/owner/payments/success',
            name: 'ownerPaymentSuccess',
            builder: (context, state) {
              final amount = int.tryParse(
                state.uri.queryParameters['amount'] ?? '',
              );
              return PaymentSuccessScreen(
                amount: amount ?? 0,
                tenantName: state.uri.queryParameters['tenantName'] ?? 'Tenant',
                propertyName:
                    state.uri.queryParameters['propertyName'] ?? 'Property',
              );
            },
          ),

          GoRoute(
            path: '/owner/payments/failure',
            name: 'ownerPaymentFailure',
            builder: (context, state) {
              final amount = int.tryParse(
                state.uri.queryParameters['amount'] ?? '',
              );
              return PaymentFailureScreen(
                amount: amount ?? 0,
                tenantName: state.uri.queryParameters['tenantName'] ?? 'Tenant',
                propertyName:
                    state.uri.queryParameters['propertyName'] ?? 'Property',
                errorMessage:
                    state.uri.queryParameters['error'] ??
                    'Payment could not be processed',
              );
            },
          ),

          /// 🧾 Owner Transactions
          GoRoute(
            path: '/owner/transactions',
            name: 'ownerTransactions',
            builder: (context, state) {
              final tenantId = state.uri.queryParameters['tenantId'];
              if (tenantId != null && tenantId.isNotEmpty) {
                return TransactionHistoryScreen(
                  actor: TransactionActor.tenant,
                  actorId: tenantId,
                );
              }
              return const TransactionHistoryScreen(
                actor: TransactionActor.owner,
              );
            },
          ),

          // ========================================================
          // 📈 REPORTS & ANALYTICS
          // ========================================================

          /// 📈 Reports & Analytics Dashboard
          GoRoute(
            path: '/owner/reports',
            name: 'ownerReports',
            builder: (context, state) => const ReportsScreen(),
          ),

          // ========================================================
          // 👤 PROFILE
          // ========================================================
          GoRoute(
            path: '/owner/profile',
            name: 'ownerProfile',
            builder: (context, state) {
              final setup = state.uri.queryParameters['setup'] == 'true';
              return ProfileScreen(isSetupMode: setup);
            },
          ),

          // ========================================================
          // 🔔 NOTIFICATIONS
          // ========================================================
          GoRoute(
            path: '/owner/notifications',
            name: 'ownerNotifications',
            builder: (context, state) => const OwnerNotificationsScreen(),
          ),

          // ========================================================
          // ⚙️ ACCOUNT & SETTINGS
          // ========================================================

          /// ⚙️ Settings - User Preferences & Configuration
          GoRoute(
            path: '/owner/subscription',
            name: 'ownerSubscription',
            builder: (context, state) => const OwnerSubscriptionScreen(),
          ),

          GoRoute(
            path: '/owner/trust-score',
            name: 'ownerTrustScore',
            builder: (context, state) => const TenantTrustScoreScreen(),
          ),

          GoRoute(
            path: '/owner/settings',
            name: 'ownerSettings',
            builder: (context, state) => const SettingsScreen(),
          ),

          /// 🏦 Bank Details
          GoRoute(
            path: '/owner/bank-details',
            name: 'ownerBankDetails',
            builder: (context, state) => const OwnerBankDetailsScreen(),
          ),

          // ========================================================
          // 🆘 SUPPORT
          // ========================================================
          GoRoute(
            path: '/owner/support',
            name: 'ownerSupport',
            builder: (context, state) => const SupportScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.red),
              const SizedBox(height: 16),
              const Text(
                'Page Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Requested path: ${state.uri}',
                style: const TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  context.go('/owner/dashboard');
                },
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      );
    },
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
