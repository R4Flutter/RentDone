import 'package:flutter/material.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/stat_card.dart';

class StatsGrid extends StatelessWidget {
  final DashboardSummary summary;
  const StatsGrid({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1200;

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: isWide ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        StatCard(
          title: 'Total Properties',
          value: summary.totalProperties.toString(),
          subtitle: '${summary.vacantProperties} vacant',
          icon: Icons.apartment_rounded,
          color: Colors.blue,
        ),
        StatCard(
          title: 'Collected',
          value: '₹${summary.collectedAmount}',
          subtitle: '${summary.collectedPayments} payments',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        ),
        StatCard(
          title: 'Pending',
          value: '₹${summary.pendingAmount}',
          subtitle: '${summary.pendingPayments} dues',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Cash / Online',
          value: '₹${summary.cashAmount} / ₹${summary.onlineAmount}',
          subtitle: 'Payment split',
          icon: Icons.payments_rounded,
          color: Colors.purple,
        ),
      ],
    );
  }
}