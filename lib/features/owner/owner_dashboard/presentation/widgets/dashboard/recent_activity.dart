import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';

class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DashboardCard(
      useGradient: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _ActivityRow(
            icon: Icons.payments_rounded,
            text: 'Payment received from Flat 203',
            time: 'Just now',
            color: scheme.primary,
          ),
          const SizedBox(height: 10),
          _ActivityRow(
            icon: Icons.person_add_alt_1_rounded,
            text: 'New tenant added',
            time: '2h ago',
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          _ActivityRow(
            icon: Icons.build_circle_outlined,
            text: 'Maintenance request submitted',
            time: '1d ago',
            color: Colors.orange,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 540.ms).slideY(begin: 0.12, end: 0);
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String time;
  final Color color;

  const _ActivityRow({
    required this.icon,
    required this.text,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: textTheme.bodyMedium?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: textTheme.bodySmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
