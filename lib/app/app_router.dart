import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rentdone/features/auth/presentation/pages/login_screen.dart';

import 'package:rentdone/features/owner/add_tenant/presentation/pages/owner_add_property.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/pages/dashboard/dashboard_scrren.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/pages/dashboard/owner_dashboard.dart';
import 'package:rentdone/features/owner/owner_payment/presenation/pages/payment_scrren.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/pages/owner_settings_scrren.dart';
import 'package:rentdone/features/owner/owners_properties/presenatation/pages/owners_properties.dart';
import 'package:rentdone/features/owner/reports/presentation/pages/report_screen.dart';
import 'package:rentdone/shared/pages/role_selection_screen.dart';
import 'package:rentdone/shared/pages/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',

    routes: [

      /// 🌊 Splash
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      /// 🎭 Role Selection
      GoRoute(
        path: '/role',
        name: 'roleSelection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      /// 🔐 Login
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      /// 🧠 OWNER SHELL (Dashboard Layout)
      ShellRoute(
        builder: (context, state, child) {
          return OwnerDashboardPage(child: child);
        },
        routes: [

          /// 📊 Dashboard
          GoRoute(
            path: '/owner/dashboard',
            name: 'ownerDashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          /// 🏠 Properties
          GoRoute(
            path: '/owner/properties',
            name: 'ownerProperties',
            builder: (context, state) => const PropertyOverviewScreen(),
          ),

          /// 👥 Tenants
          

          /// ➕ Add Tenant
          GoRoute(
            path: '/owner/tenants/add',
            name: 'addTenant',
            builder: (context, state) => const AddTenantScreen(),
          ),

          /// 💰 Payments
          GoRoute(
            path: '/owner/payments',
            name: 'ownerPayment',
            builder: (context, state) => const PaymentsScreen(),
          ),

          /// 📈 Reports
          GoRoute(
            path: '/owner/reports',
            name: 'ownerReports',
            builder: (context, state) => const ReportsScreen(),
          ),

          /// ⚙ Settings
          GoRoute(
            path: '/owner/settings',
            name: 'ownerSettings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) {
      return const Scaffold(
        body: Center(child: Text('Something went wrong')),
      );
    },
  );
});