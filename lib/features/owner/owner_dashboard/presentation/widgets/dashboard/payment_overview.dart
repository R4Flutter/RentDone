import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';

class PaymentsOverview extends StatelessWidget {
  final DashboardSummary summary;
  const PaymentsOverview({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = summary.cashAmount + summary.onlineAmount;
    final monthLabel = _monthLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Overview',
          style: textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                'Collected in $monthLabel',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                '\u20B9${_formatInr(total)}',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final cashCard = _PaymentMethodCard(
              label: 'Cash',
              amount: summary.cashAmount,
              accent: Colors.green,
              assetPath: 'assets/images/cash.png',
              subtitle: 'Cash collected',
            );
            final upiCard = _PaymentMethodCard(
              label: 'UPI',
              amount: summary.onlineAmount,
              accent: scheme.primary,
              assetPath: 'assets/images/upi.png',
              subtitle: 'UPI collected',
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: cashCard),
                  const SizedBox(width: 12),
                  Expanded(child: upiCard),
                ],
              );
            }

            return Column(
              children: [
                cashCard,
                const SizedBox(height: 12),
                upiCard,
              ],
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.12, end: 0);
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

class _PaymentMethodCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final int amount;
  final Color accent;
  final String assetPath;

  const _PaymentMethodCard({
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.accent,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return DashboardCard(
      useGradient: true,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.95),
          accent.withValues(alpha: 0.75),
          accent.withValues(alpha: 0.9),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Center(
              child: Image.asset(
                assetPath,
                height: 22,
                width: 22,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.titleLarge?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '\u20B9${_formatInr(amount)}',
                    style: textTheme.displaySmall?.copyWith(
                      color: onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
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
}
