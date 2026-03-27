import 'package:rentdone/app/app_theme.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';

class TenantDashboardScreen extends ConsumerStatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  ConsumerState<TenantDashboardScreen> createState() =>
      _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends ConsumerState<TenantDashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(transactionHistoryProvider.notifier)
            .loadInitial(actor: TransactionActor.tenant),
      );
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);

    return summaryAsync.when(
      loading: () => _CommandCenterScaffold(
        child: Center(
          child: CircularProgressIndicator(
            color: OwnerDashboardColors.brandPrimary(context),
          ),
        ),
      ),
      error: (error, _) => _CommandCenterScaffold(
        child: Center(
          child: Text(
            'Failed to load dashboard',
            style: TextStyle(color: OwnerDashboardColors.textPrimary(context)),
          ),
        ),
      ),
      data: (summary) {
        if (summary.tenantId.isEmpty) {
          return _CommandCenterScaffold(
            child: Center(
              child: Text(
                'Setting up your account...',
                style: TextStyle(
                  color: OwnerDashboardColors.textPrimary(context),
                ),
              ),
            ),
          );
        }

        final monthPaymentAsync = ref.watch(
          currentMonthPaymentProvider(summary.tenantId),
        );

        final quickActionItems = <_QuickActionItem>[
          _QuickActionItem(
            icon: Icons.payments_rounded,
            title: 'Payments',
            subtitle: 'Due and secure checkout',
            accentColor: OwnerDashboardColors.brandPrimary(context),
            onTap: () => context.push('/tenant/payments'),
          ),
          _QuickActionItem(
            icon: Icons.receipt_long_rounded,
            title: 'Transactions',
            subtitle: 'See paid amount and dates',
            accentColor: OwnerDashboardColors.brandPrimary(context),
            onTap: () => context.push('/tenant/transactions'),
          ),
          _QuickActionItem(
            icon: Icons.lock_outline_rounded,
            title: 'Vault',
            subtitle: 'Secure documents',
            accentColor: OwnerDashboardColors.brandPrimaryHover(context),
            onTap: () => context.push('/tenant/documents'),
          ),
          _QuickActionItem(
            icon: Icons.map_outlined,
            title: 'Map',
            subtitle: 'Search by city',
            accentColor: OwnerDashboardColors.brandPrimaryHover(context),
            onTap: () => context.push('/tenant/city'),
          ),
          _QuickActionItem(
            icon: Icons.person_outline_rounded,
            title: 'Profile',
            subtitle: 'Account details',
            accentColor: OwnerDashboardColors.brandPrimary(context),
            onTap: () => context.push('/tenant/profile'),
          ),
        ];

        return _CommandCenterScaffold(
          child: Stack(
            children: [
              RefreshIndicator(
                color: OwnerDashboardColors.brandPrimary(context),
                onRefresh: () async {
                  ref.invalidate(tenantDashboardProvider);
                  ref.invalidate(currentMonthPaymentProvider(summary.tenantId));
                  ref.invalidate(transactionHistoryProvider);
                  await ref
                      .read(transactionHistoryProvider.notifier)
                      .loadInitial(actor: TransactionActor.tenant, force: true);
                  await ref.read(tenantDashboardProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 140),
                  children: [
                    _TopBar(summary: summary),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _heroController,
                        curve: Curves.easeOutCubic,
                      ),
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.07),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _heroController,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: _HeroFinancialCard(
                          summary: summary,
                          controller: _heroController,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    monthPaymentAsync.when(
                      data: (payment) => _ActiveDuesCard(
                        dueAmount: payment?.amount ?? summary.dueAmount,
                        isAmountRefreshing: false,
                        onPayNow: () {
                          unawaited(
                            ref
                                .read(transactionHistoryProvider.notifier)
                                .loadInitial(actor: TransactionActor.tenant),
                          );
                          context.push('/tenant/payments');
                        },
                      ),
                      loading: () => _ActiveDuesCard(
                        dueAmount: summary.dueAmount,
                        isAmountRefreshing: true,
                        onPayNow: () => context.push('/tenant/payments'),
                      ),
                      error: (_, _) => _ActiveDuesCard(
                        dueAmount: summary.dueAmount,
                        isAmountRefreshing: false,
                        onPayNow: () => context.push('/tenant/payments'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FinancialMetricsRow(summary: summary),
                    const SizedBox(height: 28),
                    _SectionTitle(title: 'Quick Actions'),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quickActionItems.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.23,
                          ),
                      itemBuilder: (context, index) {
                        final item = quickActionItems[index];
                        return _QuickActionTile(
                          icon: item.icon,
                          title: item.title,
                          subtitle: item.subtitle,
                          accentColor: item.accentColor,
                          onTap: item.onTap,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 26,
                child: _ExpandableCommandFab(
                  onPayRent: () => context.push('/tenant/payments'),
                  onUploadDocument: () => context.push('/tenant/documents'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardPalette {
  static Color highlightAccent(BuildContext context) => Color.lerp(
    OwnerDashboardColors.brandPrimary(context),
    AppColors.white,
    OwnerDashboardColors.isDark(context) ? 0.18 : 0.08,
  )!;

  static Color positive(BuildContext context) =>
      OwnerDashboardColors.brandPrimaryHover(context);

  static Color warning(BuildContext context) => AppTheme.warningAmber;

  static LinearGradient heroGradient(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final card = OwnerDashboardColors.cardBackground(context);
    final brand = OwnerDashboardColors.brandPrimary(context);
    final elevated = OwnerDashboardColors.elevatedBackground(context);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(card, AppColors.white, isDark ? 0.04 : 0.42) ?? card,
        Color.lerp(elevated, brand, isDark ? 0.24 : 0.12) ?? elevated,
        Color.lerp(card, AppColors.black, isDark ? 0.12 : 0.02) ?? card,
      ],
    );
  }

  static LinearGradient ctaGradient(BuildContext context) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      OwnerDashboardColors.brandPrimary(context),
      OwnerDashboardColors.brandPrimaryHover(context),
    ],
  );

  static LinearGradient surfaceGradient(BuildContext context, {Color? accent}) {
    final isDark = OwnerDashboardColors.isDark(context);
    final base = OwnerDashboardColors.cardBackground(context);
    final elevated = OwnerDashboardColors.elevatedBackground(context);
    final resolvedAccent = accent ?? OwnerDashboardColors.brandPrimary(context);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, AppColors.white, isDark ? 0.04 : 0.6) ?? base,
        Color.lerp(elevated, resolvedAccent, isDark ? 0.18 : 0.08) ?? elevated,
      ],
    );
  }
}

class _CommandCenterScaffold extends StatelessWidget {
  final Widget child;

  const _CommandCenterScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _BackgroundLayerEffects(),
        SafeArea(child: child),
      ],
    );
  }
}

class _BackgroundLayerEffects extends StatelessWidget {
  const _BackgroundLayerEffects();

  @override
  Widget build(BuildContext context) {
    final topBlobColor = Color.lerp(
      OwnerDashboardColors.brandPrimary(context),
      AppColors.white,
      0.28,
    )!;
    final bottomBlobColor = Color.lerp(
      OwnerDashboardColors.brandPrimaryHover(context),
      AppColors.black,
      0.12,
    )!;
    final noiseColor = OwnerDashboardColors.isDark(context)
        ? AppColors.white.withValues(alpha: 0.02)
        : AppColors.black.withValues(alpha: 0.035);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -80,
            top: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    topBlobColor.withValues(alpha: 0.75),
                    topBlobColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -90,
            top: 130,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    bottomBlobColor.withValues(alpha: 0.85),
                    bottomBlobColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _NoisePainter(noiseColor)),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final TenantDashboardSummary summary;

  const _TopBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final elevated = OwnerDashboardColors.elevatedBackground(context);
    final border = OwnerDashboardColors.border(context);

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/rentdone_logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tenant Dashboard',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                summary.propertyName.isEmpty
                    ? 'Your financial home hub'
                    : summary.propertyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.push('/tenant/profile'),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OwnerDashboardColors.brandPrimary(context),
                border: Border.all(
                  color: OwnerDashboardColors.brandPrimary(
                    context,
                  ).withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  'C',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroFinancialCard extends StatelessWidget {
  final TenantDashboardSummary summary;
  final AnimationController controller;

  const _HeroFinancialCard({required this.summary, required this.controller});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    final greeting = _greetingText();
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final displayName = summary.tenantName.trim().isEmpty
        ? 'Tenant'
        : summary.tenantName.trim().split(RegExp(r'\s+')).first;

    return _CommandGlassCard(
      height: 214,
      padding: const EdgeInsets.all(18),
      gradient: _DashboardPalette.heroGradient(context),
      glowColor: _DashboardPalette.highlightAccent(
        context,
      ).withValues(alpha: 0.18),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -12,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final pulse =
                    0.12 + (0.08 * math.sin(controller.value * math.pi * 2));
                return Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _DashboardPalette.highlightAccent(
                          context,
                        ).withValues(alpha: pulse),
                        _DashboardPalette.highlightAccent(
                          context,
                        ).withValues(alpha: 0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $displayName',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${summary.currentMonthName.isEmpty ? 'Current' : summary.currentMonthName} Rent',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: CurvedAnimation(
                  parent: controller,
                  curve: Curves.easeOutCubic,
                ),
                builder: (context, child) {
                  final value = summary.monthlyRent * controller.value;
                  return Text(
                    _formatCurrency(value.round(), formatter),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  );
                },
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(text: 'Room ${summary.roomNumber}'),
                  _InfoPill(text: 'Due Day ${summary.rentDueDay}'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveDuesCard extends StatelessWidget {
  final int dueAmount;
  final bool isAmountRefreshing;
  final VoidCallback onPayNow;

  const _ActiveDuesCard({
    required this.dueAmount,
    required this.isAmountRefreshing,
    required this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    final isOverdue = dueAmount > 0;
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return _CommandGlassCard(
      padding: const EdgeInsets.all(16),
      gradient: _DashboardPalette.surfaceGradient(
        context,
        accent: isOverdue
            ? _DashboardPalette.warning(context)
            : _DashboardPalette.positive(context),
      ),
      glowColor: isOverdue
          ? _DashboardPalette.warning(context).withValues(alpha: 0.14)
          : _DashboardPalette.positive(context).withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Active Dues',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              _StatusTag(
                text: isOverdue ? 'Overdue' : 'No pending dues',
                color: isOverdue
                    ? _DashboardPalette.warning(context)
                    : _DashboardPalette.positive(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(dueAmount, formatter),
            style: TextStyle(
              color: textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isOverdue
                ? 'Payment pending this month'
                : 'Everything cleared for this cycle',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          if (isAmountRefreshing) ...[
            const SizedBox(height: 12),
            const _ShimmerLine(),
          ],
          const SizedBox(height: 14),
          _PrimaryGradientButton(text: 'Pay Now', onTap: onPayNow),
        ],
      ),
    );
  }
}

class _FinancialMetricsRow extends StatelessWidget {
  final TenantDashboardSummary summary;

  const _FinancialMetricsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 154,
            child: _MetricCard(
              title: 'Lifetime Paid',
              value: _formatCurrency(summary.lifetimePaid, formatter),
              accentColor: OwnerDashboardColors.brandPrimary(context),
              helperText: 'Total settled till date',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 154,
            child: _MetricCard(
              title: 'On-Time Rate',
              value: _formatPercentage(summary.onTimePaymentRate),
              accentColor: _DashboardPalette.positive(context),
              helperText: 'Payment reliability',
              progressValue: (summary.onTimePaymentRate / 100).clamp(0.0, 1.0),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;
  final String? helperText;
  final double? progressValue;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.accentColor,
    this.helperText,
    this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final isDark = OwnerDashboardColors.isDark(context);
    return _CommandGlassCard(
      padding: const EdgeInsets.all(14),
      gradient: _DashboardPalette.surfaceGradient(context, accent: accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: TextStyle(color: textSecondary, fontSize: 11),
            ),
          ],
          if (progressValue != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progressValue,
                backgroundColor: accentColor.withValues(
                  alpha: isDark ? 0.16 : 0.10,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: OwnerDashboardColors.textPrimary(context),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final brand = widget.accentColor;
    final isDark = OwnerDashboardColors.isDark(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 1.03 : 1,
        child: _CommandGlassCard(
          padding: const EdgeInsets.all(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                    OwnerDashboardColors.cardBackground(context),
                    brand,
                    isDark ? 0.16 : 0.08,
                  ) ??
                  OwnerDashboardColors.cardBackground(context),
              Color.lerp(
                    OwnerDashboardColors.elevatedBackground(context),
                    brand,
                    isDark ? 0.24 : 0.14,
                  ) ??
                  OwnerDashboardColors.elevatedBackground(context),
            ],
          ),
          glowColor: brand.withValues(alpha: 0.13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: brand.withValues(alpha: isDark ? 0.22 : 0.14),
                  border: Border.all(
                    color: brand.withValues(alpha: isDark ? 0.28 : 0.18),
                  ),
                ),
                child: Icon(widget.icon, color: brand, size: 22),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_outward_rounded, size: 16, color: brand),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });
}

class _ExpandableCommandFab extends StatefulWidget {
  final VoidCallback onPayRent;
  final VoidCallback onUploadDocument;

  const _ExpandableCommandFab({
    required this.onPayRent,
    required this.onUploadDocument,
  });

  @override
  State<_ExpandableCommandFab> createState() => _ExpandableCommandFabState();
}

class _ExpandableCommandFabState extends State<_ExpandableCommandFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = OwnerDashboardColors.brandPrimary(context);
    final actions = <_FabActionData>[
      _FabActionData('Pay Rent', Icons.payments_outlined, widget.onPayRent),
      _FabActionData(
        'Upload Document',
        Icons.upload_file_outlined,
        widget.onUploadDocument,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(actions.length, (index) {
          final animation = CurvedAnimation(
            parent: _controller,
            curve: Interval(0.08 * index, 1, curve: Curves.easeOutCubic),
          );
          return SizeTransition(
            sizeFactor: animation,
            axisAlignment: 1,
            child: FadeTransition(
              opacity: animation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MiniFabAction(
                  label: actions[index].label,
                  icon: actions[index].icon,
                  onTap: () {
                    actions[index].onTap();
                    _toggle();
                  },
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _DashboardPalette.ctaGradient(context),
              boxShadow: [
                BoxShadow(
                  color: brand.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _open ? 0.125 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.white,
                size: 34,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniFabAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniFabAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final border = OwnerDashboardColors.border(context);
    final elevated = OwnerDashboardColors.elevatedBackground(context);
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: elevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textPrimary, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FabActionData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FabActionData(this.label, this.icon, this.onTap);
}

class _CommandGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final LinearGradient? gradient;
  final Color? glowColor;
  final double? height;

  const _CommandGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.glowColor,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final radius = BorderRadius.circular(20);
    final borderColor = isDark
        ? AppColors.white.withValues(alpha: 0.14)
        : AppColors.black.withValues(alpha: 0.08);
    final shadowDark = AppColors.black.withValues(alpha: isDark ? 0.22 : 0.10);
    final shadowLight = AppColors.white.withValues(alpha: isDark ? 0.02 : 0.62);

    final content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: gradient ?? _DashboardPalette.surfaceGradient(context),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowDark,
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: shadowLight,
                blurRadius: 18,
                offset: const Offset(-6, -6),
              ),
              if (glowColor != null)
                BoxShadow(
                  color: glowColor!,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    return content;
  }
}

class _PrimaryGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryGradientButton({required this.text, required this.onTap});

  @override
  State<_PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<_PrimaryGradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.25 + (_pulseController.value * 0.15);
        final brand = OwnerDashboardColors.brandPrimary(context);
        return Material(
          color: AppColors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: widget.onTap,
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: _DashboardPalette.ctaGradient(context),
                boxShadow: [
                  BoxShadow(
                    color: brand.withValues(alpha: glow),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.text,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;

  const _InfoPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final brand = OwnerDashboardColors.brandPrimary(context);
    final isDark = OwnerDashboardColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: brand.withValues(alpha: isDark ? 0.24 : 0.16),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: OwnerDashboardColors.textPrimary(context),
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.computeLuminance() > 0.55
              ? AppColors.cFF111827
              : AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  const _ShimmerLine();

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = OwnerDashboardColors.elevatedBackground(context);
    final highlight = OwnerDashboardColors.brandPrimary(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(-1 + (_controller.value * 2), 0),
                  end: Alignment(1 + (_controller.value * 2), 0),
                  colors: [
                    base.withValues(alpha: 0.35),
                    highlight.withValues(alpha: 0.26),
                    base.withValues(alpha: 0.35),
                  ],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: Container(color: base.withValues(alpha: 0.45)),
            );
          },
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final Color color;

  const _NoisePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 14.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if (((x + y) ~/ step) % 3 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatCurrency(int amount, NumberFormat formatter) {
  return '\u20B9${formatter.format(amount)}';
}

String _formatPercentage(double value) {
  if (!value.isFinite) {
    return '0%';
  }

  final precision = value.truncateToDouble() == value ? 0 : 1;
  return '${value.toStringAsFixed(precision)}%';
}

String _greetingText() {
  final hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Good Morning';
  }
  if (hour < 17) {
    return 'Good Afternoon';
  }
  return 'Good Evening';
}
