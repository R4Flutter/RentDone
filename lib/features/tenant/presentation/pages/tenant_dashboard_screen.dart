import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
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
      loading: () => const _CommandCenterScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _CommandCenterScaffold(
        child: Center(
          child: Text(
            'Failed to load dashboard',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
      ),
      data: (summary) {
        if (summary.tenantId.isEmpty) {
          return const _CommandCenterScaffold(
            child: Center(
              child: Text(
                'Setting up your account...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final monthPaymentAsync = ref.watch(
          currentMonthPaymentProvider(summary.tenantId),
        );
        final remindersAsync = ref.watch(
          recentTenantRemindersProvider(summary.tenantId),
        );

        return _CommandCenterScaffold(
          child: Stack(
            children: [
              RefreshIndicator(
                color: _DashboardPalette.highlightAccent,
                onRefresh: () async {
                  ref.invalidate(tenantDashboardProvider);
                  ref.invalidate(currentMonthPaymentProvider(summary.tenantId));
                  ref.invalidate(
                    recentTenantRemindersProvider(summary.tenantId),
                  );
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
                          context.go('/tenant/transactions');
                        },
                      ),
                      loading: () => _ActiveDuesCard(
                        dueAmount: summary.dueAmount,
                        isAmountRefreshing: true,
                        onPayNow: () => context.go('/tenant/transactions'),
                      ),
                      error: (_, _) => _ActiveDuesCard(
                        dueAmount: summary.dueAmount,
                        isAmountRefreshing: false,
                        onPayNow: () => context.go('/tenant/transactions'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FinancialMetricsRow(summary: summary),
                    const SizedBox(height: 28),
                    _SectionTitle(title: 'Quick Actions'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _QuickActionTile(
                          icon: Icons.payments_rounded,
                          title: 'Payments',
                          subtitle: 'Due & history',
                          onTap: () => context.go('/tenant/transactions'),
                        ),
                        _QuickActionTile(
                          icon: Icons.lock_outline_rounded,
                          title: 'Vault',
                          subtitle: 'Documents',
                          onTap: () => context.go('/tenant/documents'),
                        ),
                        _QuickActionTile(
                          icon: Icons.description_outlined,
                          title: 'Complaints',
                          subtitle: 'Submit / track',
                          onTap: () => context.go('/tenant/complaints'),
                        ),
                        _QuickActionTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Profile',
                          subtitle: 'Account details',
                          onTap: () => context.go('/tenant/profile'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    remindersAsync.when(
                      data: (items) => _SystemStatusCard(
                        reminders: items,
                        onTap: () => context.go('/tenant/documents'),
                      ),
                      loading: () => const _SkeletonGlassCard(height: 92),
                      error: (_, _) => const _SkeletonGlassCard(height: 92),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                bottom: 26,
                child: _ExpandableCommandFab(
                  onPayRent: () => context.go('/tenant/transactions'),
                  onUploadDocument: () => context.go('/tenant/documents'),
                  onRaiseComplaint: () => context.go('/tenant/complaints'),
                  onContactOwner: () => context.go('/tenant/profile'),
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
  static const Color bgA = Color(0xFF0B1220);
  static const Color bgB = Color(0xFF0F1C2E);
  static const Color bgC = Color(0xFF111C30);

  static const Color primaryAccent = Color(0xFF4F7CFF);
  static const Color secondaryAccent = Color(0xFF7A5CFF);
  static const Color highlightAccent = Color(0xFF3FE0FF);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFACC15);

  static LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgA, bgB, bgC],
  );

  static LinearGradient get heroGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C2D52), Color(0xFF1B2B49), Color(0xFF151E36)],
  );

  static LinearGradient get ctaGradient => const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryAccent, secondaryAccent],
  );
}

class _CommandCenterScaffold extends StatelessWidget {
  final Widget child;

  const _CommandCenterScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: _DashboardPalette.backgroundGradient),
      child: Stack(
        children: [
          const _BackgroundLayerEffects(),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _BackgroundLayerEffects extends StatelessWidget {
  const _BackgroundLayerEffects();

  @override
  Widget build(BuildContext context) {
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
                    _DashboardPalette.primaryAccent.withValues(alpha: 0.28),
                    _DashboardPalette.primaryAccent.withValues(alpha: 0.0),
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
                    _DashboardPalette.secondaryAccent.withValues(alpha: 0.22),
                    _DashboardPalette.secondaryAccent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _NoisePainter())),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final dynamic summary;

  const _TopBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                'Tenant Command Center',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.96),
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
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Scaffold.maybeOf(context)?.openDrawer(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Icon(
                Icons.menu_rounded,
                color: scheme.onPrimary.withValues(alpha: 0.92),
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroFinancialCard extends StatelessWidget {
  final dynamic summary;
  final AnimationController controller;

  const _HeroFinancialCard({required this.summary, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    final greeting = _greetingText();

    return _CommandGlassCard(
      height: 214,
      padding: const EdgeInsets.all(18),
      gradient: _DashboardPalette.heroGradient,
      glowColor: _DashboardPalette.highlightAccent.withValues(alpha: 0.25),
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
                        _DashboardPalette.highlightAccent.withValues(
                          alpha: pulse,
                        ),
                        _DashboardPalette.highlightAccent.withValues(alpha: 0),
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
                '$greeting, Tenant',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.82),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Primary Balance',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.68),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: CurvedAnimation(
                  parent: controller,
                  curve: Curves.easeOutCubic,
                ),
                builder: (context, child) {
                  final value = (summary.monthlyRent as int) * controller.value;
                  return Text(
                    '₹${formatter.format(value.round())}',
                    style: TextStyle(
                      color: scheme.onPrimary,
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
    final scheme = Theme.of(context).colorScheme;
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    final isOverdue = dueAmount > 0;

    return _CommandGlassCard(
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      glowColor: isOverdue
          ? _DashboardPalette.warning.withValues(alpha: 0.2)
          : _DashboardPalette.success.withValues(alpha: 0.17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Active Dues',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              _StatusTag(
                text: isOverdue ? 'Overdue' : 'No pending dues',
                color: isOverdue
                    ? _DashboardPalette.warning
                    : _DashboardPalette.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${formatter.format(dueAmount)}',
            style: TextStyle(
              color: scheme.onPrimary,
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
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
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
  final dynamic summary;

  const _FinancialMetricsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Lifetime Paid',
            value: '₹${formatter.format(summary.lifetimePaid)}',
            accentColor: _DashboardPalette.primaryAccent,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _MetricCard(
            title: 'Growth',
            value: '+12.4%',
            accentColor: _DashboardPalette.success,
            showSparkline: true,
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
  final bool showSparkline;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.accentColor,
    this.showSparkline = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _CommandGlassCard(
      padding: const EdgeInsets.all(14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.09),
          accentColor.withValues(alpha: 0.07),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 24,
            child: showSparkline ? const _Sparkline() : const SizedBox.shrink(),
          ),
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
        color: Colors.white.withValues(alpha: 0.95),
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
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              Colors.white.withValues(alpha: 0.08),
              _DashboardPalette.primaryAccent.withValues(alpha: 0.05),
            ],
          ),
          glowColor: _DashboardPalette.primaryAccent.withValues(alpha: 0.16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.icon,
                color: scheme.onPrimary.withValues(alpha: 0.95),
                size: 22,
              ),
              const Spacer(),
              Text(
                widget.title,
                style: TextStyle(
                  color: scheme.onPrimary,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.66),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: scheme.onPrimary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  final List<dynamic> reminders;
  final VoidCallback onTap;

  const _SystemStatusCard({required this.reminders, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = reminders.isEmpty
        ? 'All updates are synced'
        : (reminders.first.title.isNotEmpty
              ? reminders.first.title
              : reminders.first.body);

    return _CommandGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.09),
          _DashboardPalette.success.withValues(alpha: 0.05),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: _DashboardPalette.success.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Vault Updates',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _DashboardPalette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onPrimary.withValues(alpha: 0.78),
          ),
        ],
      ),
    );
  }
}

class _ExpandableCommandFab extends StatefulWidget {
  final VoidCallback onPayRent;
  final VoidCallback onUploadDocument;
  final VoidCallback onRaiseComplaint;
  final VoidCallback onContactOwner;

  const _ExpandableCommandFab({
    required this.onPayRent,
    required this.onUploadDocument,
    required this.onRaiseComplaint,
    required this.onContactOwner,
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
    final actions = <_FabActionData>[
      _FabActionData('Pay Rent', Icons.payments_outlined, widget.onPayRent),
      _FabActionData(
        'Upload Document',
        Icons.upload_file_outlined,
        widget.onUploadDocument,
      ),
      _FabActionData(
        'Raise Complaint',
        Icons.report_problem_outlined,
        widget.onRaiseComplaint,
      ),
      _FabActionData(
        'Contact Owner',
        Icons.call_outlined,
        widget.onContactOwner,
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
              gradient: _DashboardPalette.ctaGradient,
              boxShadow: [
                BoxShadow(
                  color: _DashboardPalette.primaryAccent.withValues(
                    alpha: 0.45,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _open ? 0.125 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
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
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final Color? glowColor;
  final double? height;

  const _CommandGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.gradient,
    this.glowColor,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    final content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient:
                gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 60,
                offset: const Offset(0, 20),
              ),
              if (glowColor != null)
                BoxShadow(
                  color: glowColor!,
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
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
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: widget.onTap,
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: _DashboardPalette.ctaGradient,
                boxShadow: [
                  BoxShadow(
                    color: _DashboardPalette.primaryAccent.withValues(
                      alpha: glow,
                    ),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.86),
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
          color: Colors.white.withValues(alpha: 0.9),
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
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.12),
                  ],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: Container(color: Colors.white.withValues(alpha: 0.2)),
            );
          },
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(),
      size: const Size(double.infinity, 24),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.82, 0.74, 0.77, 0.66, 0.63, 0.58, 0.46, 0.31];
    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final y = size.height * points[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [_DashboardPalette.success, _DashboardPalette.highlightAccent],
      ).createShader(Offset.zero & size)
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = _DashboardPalette.highlightAccent.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkeletonGlassCard extends StatelessWidget {
  final double height;

  const _SkeletonGlassCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return _CommandGlassCard(height: height, child: const SizedBox.shrink());
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.02);
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
