import 'package:flutter/material.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/pages/dashboard/dashboard_body.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // 🔥 near-black in dark
      body: const DashboardBody(),
    );
  }
}