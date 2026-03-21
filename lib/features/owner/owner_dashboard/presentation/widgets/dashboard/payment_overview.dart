import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/dashboard_summary.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';

class PaymentsOverview extends StatelessWidget {
  final DashboardSummary summary;
  const PaymentsOverview({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final monthLabel = _monthLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Overview',
          style: textTheme.titleLarge?.copyWith(
            color: OwnerDashboardColors.textPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Collected in $monthLabel',
          style: textTheme.bodySmall?.copyWith(
            color: OwnerDashboardColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final cashCard = _PaymentMethodCard(
              label: 'Cash',
              amount: summary.cashAmount,
              tone: OwnerDashboardColors.cashTone(context),
              assetPath: 'assets/images/cash.png',
              subtitle: 'Cash collected',
            );
            final upiCard = _PaymentMethodCard(
              label: 'UPI',
              amount: summary.onlineAmount,
              tone: OwnerDashboardColors.upiTone(context),
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
              children: [cashCard, const SizedBox(height: 12), upiCard],
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.12, end: 0);
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
  final OwnerDashboardTone tone;
  final String assetPath;

  const _PaymentMethodCard({
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.tone,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DashboardCard(
      useGradient: false,
      backgroundColor: OwnerDashboardColors.cardBackground(context),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 260;
          final amountStyle = compact
              ? textTheme.titleLarge?.copyWith(
                  color: OwnerDashboardColors.textPrimary(context),
                  fontWeight: FontWeight.w800,
                )
              : textTheme.displaySmall?.copyWith(
                  color: OwnerDashboardColors.textPrimary(context),
                  fontWeight: FontWeight.w800,
                );

          final iconShell = Container(
            height: compact ? 40 : 44,
            width: compact ? 40 : 44,
            decoration: BoxDecoration(
              color: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Image.asset(
                assetPath,
                height: compact ? 20 : 22,
                width: compact ? 20 : 22,
                color: OwnerDashboardColors.brandPrimary(context),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  color: OwnerDashboardColors.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text('\u20B9${_formatInr(amount)}', style: amountStyle),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: OwnerDashboardColors.textSecondary(context),
                ),
              ),
            ],
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconShell,
                const SizedBox(width: 10),
                Expanded(child: content),
              ],
            );
          }

          return Row(
            children: [
              iconShell,
              const SizedBox(width: 12),
              Expanded(child: content),
            ],
          );
        },
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
