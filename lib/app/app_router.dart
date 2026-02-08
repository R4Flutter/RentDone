import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/presentation/pages/login_screen.dart';
import 'package:rentdone/features/owner/presentation/pages/owner_dashboard.dart';

import 'package:rentdone/shared/pages/role_selection_screen.dart';
import 'package:rentdone/shared/pages/splash_screen.dart';


/// App-level router (ONLY splash for now)
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',

    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/role',
        name: 'roleSelection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),

       GoRoute(
        path: '/owner_dashboard',
        name: 'owner_dashboard',
        builder: (context, state) =>  OwnerDashboardPage(),
      ),

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>  LoginPage(),
      ),
    ],

    errorBuilder: (context, state) {
      return const Scaffold(body: Center(child: Text('Something went wrong')));
    },
  );
});
