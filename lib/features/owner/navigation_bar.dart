import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/botttom_nav_bar.dart';

class RentDoneNavigation extends StatelessWidget {
  final Widget child;

  const RentDoneNavigation({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: child,

      bottomNavigationBar: PinterestMorphNavBar(
        currentIndex: _calculateIndex(context),
        onTap: (index) {
          switch (index) {
            case 0:
              context.goNamed('ownerDashboard');
              break;
            case 1:
              context.goNamed('addTenant');
              break;
            case 2:
              context.goNamed('manageProperties');
              break;
          }
        },
      ),
    );
  }


    int _calculateIndex(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;

  if (location.startsWith('/owner/dashboard')) {
    return 0;
  }

  if (location.startsWith('/owner/tenants')) {
    return 1;
  }

  if (location.startsWith('/owner/properties')) {
    return 2;
  }

  if (location.startsWith('/owner/payments')) {
    return 3;
  }

  if (location.startsWith('/owner/reports')) {
    return 4;
  }

  if (location.startsWith('/owner/settings')) {
    return 5;
  }

  return 0;
}
  }

