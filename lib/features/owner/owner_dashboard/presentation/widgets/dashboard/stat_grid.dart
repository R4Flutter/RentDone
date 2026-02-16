import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/stat_card.dart';

class StatsGrid extends StatelessWidget {
  final DashboardSummary summary;
  const StatsGrid({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1200 ? 4 : width >= 900 ? 3 : 2;
    final aspect = width >= 1200
        ? 1.35
        : width >= 900
            ? 1.2
            : 0.9;
    final monthLabel = _monthLabel();

    final cards = [
      StatCard(
        title: 'Total Properties',
        value: summary.totalProperties.toString(),
        subtitle: '${summary.vacantProperties} vacant',
        icon: Icons.apartment_rounded,
        color: Colors.blue,
        assetPath: 'assets/images/property.png',
      ),
      StatCard(
        title: 'Total Tenants',
        value: summary.totalTenants.toString(),
        subtitle: 'Active tenants',
        icon: Icons.people_alt_rounded,
        color: Colors.teal,
        assetPath: 'assets/images/tenant_final.png',
      ),
      StatCard(
        title: 'Collected',
        value: '\u20B9${_formatInr(summary.collectedAmount)}',
        subtitle: '$monthLabel - ${summary.collectedPayments} payments',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        assetPath: 'assets/images/collected.png',
      ),
      StatCard(
        title: 'Pending',
        value: '\u20B9${_formatInr(summary.pendingAmount)}',
        subtitle: summary.pendingTenants > 0
            ? '$monthLabel - ${summary.pendingTenants} tenants pending'
            : '$monthLabel - ${summary.pendingPayments} dues',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        assetPath: 'assets/images/pending.png',
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: aspect,
      children: List.generate(cards.length, (index) {
        return cards[index]
            .animate()
            .fadeIn(duration: 400.ms, delay: (90 * index).ms)
            .slideY(begin: 0.15, end: 0);
      }),
    );
  }

  String _formatInr(int value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    if (digits.length <= 3) return '$sign$digits';

    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) {
      parts.insert(0, rest);
    }
    return '$sign${parts.join(',')},$last3';
  }

  String _monthLabel() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }
}
