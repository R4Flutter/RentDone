import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/owner_sidebar.dart';

class OwnerDashboardPage extends ConsumerWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dashboardProvider);

    return Scaffold(
      body: Row(
        children: [
          const OwnerSidebar(),

          // MAIN CONTENT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: IndexedStack(
                index: index,
                children: const [
                  Center(child: Text('Dashboard View')),
                  Center(child: Text('Properties View')),
                  Center(child: Text('Tenants View')),
                  Center(child: Text('Payments View')),
                  Center(child: Text('Reports View')),
                  Center(child: Text('Settings View')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}