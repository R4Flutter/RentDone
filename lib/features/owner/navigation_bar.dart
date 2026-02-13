import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/botttom_nav_bar.dart';

class RentDoneNavigation extends StatelessWidget {
  final Widget child;

  const RentDoneNavigation({
    super.key,
    required this.child,
  });

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
              context.go('/owner/dashboard');
              break;
            case 1:
              context.go('/owner/add-tenant');
              break;
            case 2:
              context.go('/owner/properties');
              break;
          }
        },
      ),
    );
  }

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    if (location.contains('add-tenant')) return 1;
    if (location.contains('properties')) return 2;
    return 0;
  }
}