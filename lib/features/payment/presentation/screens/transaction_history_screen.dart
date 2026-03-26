import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_dashboard_provider.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_di.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/payment/presentation/widgets/payment_badge.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentdone/features/payment/data/gateways/payment_gateway.dart';
import 'package:rentdone/features/owner/owner_payment/models/payment_state.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/razorpay_service.dart'
    hide razorpayServiceProvider;

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final TransactionActor actor;
  final String? actorId;

  const TransactionHistoryScreen({
    super.key,
    this.actor = TransactionActor.tenant,
    this.actorId,
  });

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(transactionHistoryProvider.notifier)
          .loadInitial(actor: widget.actor, actorId: widget.actorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryProvider);
    final data = state.asData?.value ?? TransactionHistoryState.initial();
    final showBlockingError = state.hasError && state.asData == null;
    final showInitialLoader = state.isLoading && data.transactions.isEmpty;
    final isTenant = widget.actor == TransactionActor.tenant;
    final summaryAsync = ref.watch(tenantDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        surfaceTintColor: AppColors.transparent,
        foregroundColor: _PaymentScreenTheme.textPrimary(context),
        title: Text(
          isTenant ? 'Payments' : 'Transactions',
          style: TextStyle(
            color: _PaymentScreenTheme.textPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: _PaymentScreenTheme.pageGradient(context),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _FintechBackgroundEffects(
                noiseColor: _PaymentScreenTheme.noise(context),
              ),
            ),
            showBlockingError
                ? _HistoryError(
                    error: state.error ?? 'Unable to load transactions',
                    onRetry: () => ref
                        .read(transactionHistoryProvider.notifier)
                        .loadInitial(
                          actor: widget.actor,
                          actorId: widget.actorId,
                          force: true,
                        ),
                  )
                : Builder(
                    builder: (_) {
                      final latestAmount = data.transactions.isEmpty
                          ? 0
                          : data.transactions.first.amount;
                      final suggestedAmount = summaryAsync.maybeWhen(
                        data: (summary) {
                          if (summary.dueAmount > 0) {
                            return summary.dueAmount;
                          }
                          if (summary.monthlyRent > 0) {
                            return summary.monthlyRent;
                          }
                          return latestAmount;
                        },
                        orElse: () => latestAmount,
                      );

                      final ownerDetailsAsync = summaryAsync.maybeWhen(
                        data: (summary) => summary.tenantId.isEmpty
                            ? const AsyncValue<TenantOwnerDetails?>.data(null)
                            : ref.watch(
                                tenantOwnerDetailsProvider(summary.tenantId),
                              ),
                        orElse: () =>
                            const AsyncValue<TenantOwnerDetails?>.loading(),
                      );

                      final ownerUpiId = ownerDetailsAsync.maybeWhen(
                        data: (details) => details?.ownerUpiId ?? '',
                        orElse: () => '',
                      );

                      final ownerName = ownerDetailsAsync.maybeWhen(
                        data: (details) {
                          final preferredName = (details?.ownerName ?? '')
                              .trim();
                          if (preferredName.isNotEmpty) {
                            return preferredName;
                          }
                          return summaryAsync.maybeWhen(
                            data: (summary) => summary.propertyName,
                            orElse: () => 'Owner',
                          );
                        },
                        orElse: () => 'Owner',
                      );
                      final isFirstPayment = !data.transactions.any(
                        (tx) => tx.status.toLowerCase() == 'success',
                      );

                      return Column(
                        children: [
                          if (isTenant)
                            _TenantPaymentHero(
                              latestAmount: suggestedAmount,
                              ownerUpiId: ownerUpiId,
                              ownerName: ownerName,
                              isFirstPayment: isFirstPayment,
                            ),
                          _FilterBar(
                            selectedYear: data.selectedYear,
                            selectedStatus: data.selectedStatus,
                            onYearChanged: (year) => ref
                                .read(transactionHistoryProvider.notifier)
                                .setFilters(year: year),
                            onStatusChanged: (status) => ref
                                .read(transactionHistoryProvider.notifier)
                                .setFilters(status: status),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              color: _PaymentScreenTheme.brand(context),
                              onRefresh: () async {
                                await ref
                                    .read(transactionHistoryProvider.notifier)
                                    .refresh();
                              },
                              child: showInitialLoader
                                  ? const _TransactionListSkeleton()
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        8,
                                        20,
                                        120,
                                      ),
                                      itemBuilder: (context, index) {
                                        if (index == data.transactions.length) {
                                          return _LoadMoreTile(
                                            hasMore: data.hasMore,
                                            isLoadingMore: data.isLoadingMore,
                                            onLoadMore: () => ref
                                                .read(
                                                  transactionHistoryProvider
                                                      .notifier,
                                                )
                                                .loadMore(),
                                          );
                                        }

                                        final tx = data.transactions[index];
                                        return _TransactionTile(
                                          transaction: tx,
                                        );
                                      },
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 14),
                                      itemCount: data.transactions.length + 1,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _PaymentScreenTheme {
  static bool isDark(BuildContext context) =>
      OwnerDashboardColors.isDark(context);

  static Color brand(BuildContext context) =>
      OwnerDashboardColors.brandPrimary(context);

  static Color brandStrong(BuildContext context) =>
      OwnerDashboardColors.brandPrimaryHover(context);

  static Color textPrimary(BuildContext context) =>
      OwnerDashboardColors.textPrimary(context);

  static Color textSecondary(BuildContext context) =>
      OwnerDashboardColors.textSecondary(context);

  static Color textMuted(BuildContext context) =>
      OwnerDashboardColors.textMuted(context);

  static Color surface(BuildContext context) =>
      OwnerDashboardColors.cardBackground(context);

  static Color elevated(BuildContext context) =>
      OwnerDashboardColors.elevatedBackground(context);

  static Color border(BuildContext context) =>
      OwnerDashboardColors.border(context);

  static Color success(BuildContext context) => AppTheme.successGreen;

  static Color error(BuildContext context) => AppTheme.errorRed;

  static Color noise(BuildContext context) => isDark(context)
      ? AppColors.white.withValues(alpha: 0.02)
      : AppColors.black.withValues(alpha: 0.035);

  static LinearGradient pageGradient(BuildContext context) =>
      OwnerDashboardColors.ownerPageBackgroundGradient(context);

  static LinearGradient ctaGradient(BuildContext context) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brand(context), brandStrong(context)],
  );

  static LinearGradient surfaceGradient(BuildContext context, {Color? accent}) {
    final isDarkMode = isDark(context);
    final base = surface(context);
    final elevatedBase = elevated(context);
    final resolvedAccent = accent ?? brand(context);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, AppColors.white, isDarkMode ? 0.04 : 0.60) ?? base,
        Color.lerp(elevatedBase, resolvedAccent, isDarkMode ? 0.18 : 0.08) ??
            elevatedBase,
      ],
    );
  }

  static LinearGradient heroGradient(BuildContext context) {
    final isDarkMode = isDark(context);
    final base = surface(context);
    final elevatedBase = elevated(context);
    final brandColor = brand(context);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(base, AppColors.white, isDarkMode ? 0.04 : 0.42) ?? base,
        Color.lerp(elevatedBase, brandColor, isDarkMode ? 0.24 : 0.12) ??
            elevatedBase,
        Color.lerp(base, AppColors.black, isDarkMode ? 0.12 : 0.02) ?? base,
      ],
    );
  }
}

class _TransactionListSkeleton extends StatelessWidget {
  const _TransactionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => _PremiumGlassCard(
        borderRadius: BorderRadius.circular(18),
        child: const SizedBox(height: 126),
      ),
    );
  }
}

class _FintechBackgroundEffects extends StatelessWidget {
  final Color noiseColor;

  const _FintechBackgroundEffects({required this.noiseColor});

  @override
  Widget build(BuildContext context) {
    final topBlobColor = OwnerDashboardColors.ownerTopBlobColor(context);
    final bottomBlobColor = OwnerDashboardColors.ownerBottomBlobColor(context);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: -70,
            top: -40,
            child: Container(
              width: 230,
              height: 230,
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
            top: 120,
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

class _PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Color? glowColor;

  const _PremiumGlassCard({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.gradient,
    this.onTap,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = _PaymentScreenTheme.isDark(context);
    final borderColor = isDark
        ? AppColors.white.withValues(alpha: 0.14)
        : AppColors.black.withValues(alpha: 0.08);
    final shadowDark = AppColors.black.withValues(alpha: isDark ? 0.22 : 0.10);
    final shadowLight = AppColors.white.withValues(alpha: isDark ? 0.02 : 0.62);

    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: gradient ?? _PaymentScreenTheme.surfaceGradient(context),
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
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: AppColors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final int? selectedYear;
  final String selectedStatus;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<String> onStatusChanged;

  const _FilterBar({
    required this.selectedYear,
    required this.selectedStatus,
    required this.onYearChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final years = _yearOptions();
    final statuses = ['all', 'success', 'failed', 'pending', 'refunded'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction History',
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DarkDropdown<int?>(
                value: selectedYear,
                hint: 'All Years',
                items: years
                    .map(
                      (year) => DropdownMenuItem<int?>(
                        value: year,
                        child: Text(
                          year == null ? 'All Years' : year.toString(),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onYearChanged,
              ),
              _DarkDropdown<String>(
                value: selectedStatus,
                hint: 'All',
                items: statuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<int?> _yearOptions() {
    final now = DateTime.now().year;
    return [null, now, now - 1, now - 2];
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionRecord transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final textPrimary = _PaymentScreenTheme.textPrimary(context);
    final textSecondary = _PaymentScreenTheme.textSecondary(context);
    return _PremiumGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      gradient: _PaymentScreenTheme.surfaceGradient(
        context,
        accent: _PaymentScreenTheme.brand(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatCurrency(transaction.amount),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              PaymentBadge(
                label: transaction.status.toUpperCase(),
                status: transaction.status,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Gateway: ${transaction.gateway}',
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Transaction ID: ${transaction.transactionId}',
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${_formatDate(transaction.createdAt)}',
            style: TextStyle(color: textSecondary),
          ),
          if (transaction.failureReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Failure: ${transaction.failureReason}',
              style: TextStyle(color: _PaymentScreenTheme.error(context)),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                showModalBottomSheet(
                  backgroundColor: AppColors.transparent,
                  context: context,
                  builder: (_) =>
                      _TransactionDetailSheet(transaction: transaction),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: _PaymentScreenTheme.brand(context),
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockGlowButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _LockGlowButton({required this.onPressed, required this.child});

  @override
  State<_LockGlowButton> createState() => _LockGlowButtonState();
}

class _LockGlowButtonState extends State<_LockGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = 0.24 + (_glowController.value * 0.18);
        final brand = _PaymentScreenTheme.brand(context);
        return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: _PaymentScreenTheme.ctaGradient(context),
                boxShadow: [
                  BoxShadow(
                    color: brand.withValues(alpha: glow),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  final TransactionRecord transaction;

  const _TransactionDetailSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final textPrimary = _PaymentScreenTheme.textPrimary(context);
    final success = _PaymentScreenTheme.success(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: _PremiumGlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(20),
          gradient: _PaymentScreenTheme.surfaceGradient(
            context,
            accent: success,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: success.withValues(alpha: 0.18),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: success,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Transaction Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  PaymentBadge(
                    label: transaction.status.toUpperCase(),
                    status: transaction.status,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DetailRow(
                label: 'Amount',
                value: _formatCurrency(transaction.amount),
                highlight: true,
              ),
              _DetailRow(label: 'Gateway', value: transaction.gateway),
              _DetailRow(label: 'Payment ID', value: transaction.paymentId),
              _DetailRow(
                label: 'Transaction ID',
                value: transaction.transactionId,
              ),
              _DetailRow(
                label: 'Created',
                value: _formatDate(transaction.createdAt),
              ),
              if (transaction.completedAt != null)
                _DetailRow(
                  label: 'Completed',
                  value: _formatDate(transaction.completedAt!),
                ),
              if (transaction.failureReason != null)
                _DetailRow(
                  label: 'Failure',
                  value: transaction.failureReason!,
                  tone: _PaymentScreenTheme.error(context),
                ),
              const SizedBox(height: 10),
              _LockGlowButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: AppColors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Close',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadMoreTile extends StatelessWidget {
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _LoadMoreTile({
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: Text(
            'No more transactions',
            style: TextStyle(color: _PaymentScreenTheme.textSecondary(context)),
          ),
        ),
      );
    }

    if (isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: CircularProgressIndicator(
            color: _PaymentScreenTheme.brand(context),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: _PremiumGlassCard(
        borderRadius: BorderRadius.circular(14),
        onTap: onLoadMore,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: Text(
            'Load more',
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _HistoryError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isOffline = error is NetworkFailure;
    final message = isOffline ? 'You are offline.' : error.toString();
    final textPrimary = _PaymentScreenTheme.textPrimary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: _PaymentScreenTheme.brand(context),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textPrimary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _PaymentScreenTheme.brand(context),
                foregroundColor: AppColors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantPaymentHero extends ConsumerStatefulWidget {
  final int latestAmount;
  final String ownerUpiId;
  final String ownerName;
  final bool isFirstPayment;

  const _TenantPaymentHero({
    required this.latestAmount,
    required this.ownerUpiId,
    required this.ownerName,
    required this.isFirstPayment,
  });

  @override
  ConsumerState<_TenantPaymentHero> createState() => _TenantPaymentHeroState();
}

class _TenantPaymentHeroState extends ConsumerState<_TenantPaymentHero>
    with TickerProviderStateMixin {
  late final TextEditingController _amountController;
  bool _isLaunchingUpi = false;
  bool _isPayingRazorpay = false;
  late final AnimationController _introController;
  late final AnimationController _qrGlowController;
  late final FocusNode _amountFocusNode;
  bool _amountFocused = false;

  bool get _isHighValuePayment {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    return amount >= 50000;
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.latestAmount > 0 ? widget.latestAmount.toString() : '',
    );
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _qrGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _amountFocusNode = FocusNode()
      ..addListener(() {
        setState(() => _amountFocused = _amountFocusNode.hasFocus);
      });
  }

  @override
  void didUpdateWidget(covariant _TenantPaymentHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_amountController.text.trim().isEmpty && widget.latestAmount > 0) {
      _amountController.text = widget.latestAmount.toString();
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _qrGlowController.dispose();
    _amountFocusNode.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Map<String, String> _upiQuery({required int amount}) {
    final normalizedUpiId = widget.ownerUpiId.trim();
    if (normalizedUpiId.isEmpty) {
      return const {};
    }

    final payeeName = widget.ownerName.trim().isEmpty
        ? 'Owner'
        : widget.ownerName.trim();
    final amountValue = (amount <= 0 ? 1 : amount).toStringAsFixed(2);

    return {
      'pa': normalizedUpiId,
      'pn': payeeName,
      'am': amountValue,
      'cu': 'INR',
      'tn': 'Rent payment via RentDone',
    };
  }

  String _buildUpiUri({required int amount}) {
    final query = _upiQuery(amount: amount);
    if (query.isEmpty) {
      return '';
    }

    final uri = Uri(scheme: 'upi', host: 'pay', queryParameters: query);

    return uri.toString();
  }

  String _buildTezUri({required int amount}) {
    final query = _upiQuery(amount: amount);
    if (query.isEmpty) {
      return '';
    }

    final uri = Uri(
      scheme: 'tez',
      host: 'upi',
      path: '/pay',
      queryParameters: query,
    );

    return uri.toString();
  }

  Future<void> _openUpiApp(BuildContext context, {required int amount}) async {
    final upiUri = _buildUpiUri(amount: amount);
    if (upiUri.isEmpty || _isLaunchingUpi) {
      return;
    }

    setState(() => _isLaunchingUpi = true);

    final uriCandidates = <String>[
      _buildTezUri(amount: amount),
      upiUri,
    ].where((value) => value.isNotEmpty).toSet().toList();

    var opened = false;

    for (final raw in uriCandidates) {
      final uri = Uri.parse(raw);
      final canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        continue;
      }
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (opened) {
        break;
      }
    }

    if (!opened) {
      opened = await launchUrl(
        Uri.parse(upiUri),
        mode: LaunchMode.externalApplication,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() => _isLaunchingUpi = false);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open UPI app. Check UPI app and owner UPI ID.',
          ),
        ),
      );
    }
  }

  Future<_TrustFlowResult> _payRazorpay() async {
    if (_isPayingRazorpay) {
      return const _TrustFlowResult(
        isSuccess: false,
        message: 'Payment is already being processed.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _TrustFlowResult(
        isSuccess: false,
        message: 'Please sign in to continue.',
      );
    }

    setState(() => _isPayingRazorpay = true);

    try {
      final razorpayGateway = TenantRazorpayGatewayAdapter(
        ref.read(razorpayServiceProvider),
      );
      final notifier = ref.read(paymentDashboardProvider.notifier);

      final intent = await notifier.createAndPay(
        gateway: 'razorpay',
        paymentGateway: razorpayGateway,
        tenantEmail: user.email ?? '',
        tenantPhone: user.phoneNumber ?? '',
      );

      if (!context.mounted) {
        return const _TrustFlowResult(
          isSuccess: false,
          message: 'Payment result is unavailable right now.',
        );
      }

      if (intent != null) {
        ref.read(transactionHistoryProvider.notifier).refresh();
        return const _TrustFlowResult(
          isSuccess: true,
          message: 'Your payment has been successfully completed.',
        );
      } else {
        final payState = ref.read(paymentDashboardProvider).asData?.value;
        final msg = payState?.message ?? 'Payment failed. Please try again.';
        return _TrustFlowResult(isSuccess: false, message: msg);
      }
    } catch (e) {
      return _TrustFlowResult(
        isSuccess: false,
        message: 'Error while processing payment: $e',
      );
    } finally {
      if (mounted) setState(() => _isPayingRazorpay = false);
    }
  }

  Future<void> _startRazorpayTrustFlow(BuildContext context) async {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final due = ref.read(paymentDashboardProvider).asData?.value.due;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    final result = await showModalBottomSheet<_TrustFlowResult>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _TenantPaymentTrustFlowSheet(
          rentAmount: due?.monthlyRent ?? widget.latestAmount,
          lateFeeAmount: due?.lateFeeAmount ?? 0,
          totalPayable: amount,
          ownerName: widget.ownerName,
          isFirstPayment: widget.isFirstPayment,
          isHighValuePayment: _isHighValuePayment,
          isProcessing: _isPayingRazorpay,
          onConfirmPay: _payRazorpay,
        );
      },
    );

    if (!context.mounted || result == null) {
      return;
    }

    final snackColor = result.isSuccess
        ? _PaymentScreenTheme.success(context)
        : _PaymentScreenTheme.error(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: snackColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestAmount = widget.latestAmount;
    final enteredAmount =
        int.tryParse(_amountController.text.trim()) ?? latestAmount;
    final brand = _PaymentScreenTheme.brand(context);
    final textPrimary = _PaymentScreenTheme.textPrimary(context);
    final textSecondary = _PaymentScreenTheme.textSecondary(context);
    final textMuted = _PaymentScreenTheme.textMuted(context);
    final success = _PaymentScreenTheme.success(context);
    final border = _PaymentScreenTheme.border(context);
    final isDark = _PaymentScreenTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _introController,
          curve: Curves.easeOutCubic,
        ),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _introController,
                  curve: Curves.easeOut,
                ),
              ),
          child: _PremiumGlassCard(
            padding: const EdgeInsets.all(18),
            gradient: _PaymentScreenTheme.heroGradient(context),
            glowColor: brand.withValues(alpha: 0.12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: brand.withValues(alpha: isDark ? 0.22 : 0.14),
                        ),
                      ),
                      child: Text(
                        'RENTDONE UPI',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Secure',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Scan & Pay Rent',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _QrContainer(
                  amountTextProvider: () => _amountController.text.trim(),
                  buildUpiUri: _buildUpiUri,
                  glowAnimation: _qrGlowController,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _amountFocused ? brand : border),
                    gradient: _PaymentScreenTheme.surfaceGradient(
                      context,
                      accent: _amountFocused ? brand : null,
                    ),
                    boxShadow: [
                      if (_amountFocused)
                        BoxShadow(
                          color: brand.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          focusNode: _amountFocusNode,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            hintText: latestAmount > 0
                                ? latestAmount.toString()
                                : '0',
                            hintStyle: TextStyle(
                              color: textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.ownerUpiId.trim().isEmpty
                            ? 'Owner UPI not available'
                            : widget.ownerUpiId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: success.withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Encrypted',
                        style: TextStyle(color: textPrimary, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _LockGlowButton(
                  onPressed: _isLaunchingUpi
                      ? null
                      : () {
                          final amount =
                              int.tryParse(_amountController.text.trim()) ?? 0;
                          _openUpiApp(context, amount: amount);
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isLaunchingUpi
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.white,
                              size: 18,
                            ),
                      const SizedBox(width: 8),
                      Text(
                        _isLaunchingUpi
                            ? 'Opening payment app...'
                            : 'Pay with UPI (${_formatCurrency(enteredAmount)})',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _RazorpayPayButton(
                  isLoading: _isPayingRazorpay,
                  onPressed: () => _startRazorpayTrustFlow(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RazorpayPayButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _RazorpayPayButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final brand = _PaymentScreenTheme.brand(context);
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: _PaymentScreenTheme.ctaGradient(context),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: brand.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              else
                const Icon(
                  Icons.lock_rounded,
                  color: AppColors.white,
                  size: 18,
                ),
              const SizedBox(width: 8),
              Text(
                isLoading ? 'Processing...' : 'Pay with Razorpay',
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TrustFlowStep {
  summary,
  method,
  reassurance,
  processing,
  success,
  failure,
}

class _TrustFlowResult {
  final bool isSuccess;
  final String message;

  const _TrustFlowResult({required this.isSuccess, required this.message});
}

class _TenantPaymentTrustFlowSheet extends StatefulWidget {
  final int rentAmount;
  final int lateFeeAmount;
  final int totalPayable;
  final String ownerName;
  final bool isFirstPayment;
  final bool isHighValuePayment;
  final bool isProcessing;
  final Future<_TrustFlowResult> Function() onConfirmPay;

  const _TenantPaymentTrustFlowSheet({
    required this.rentAmount,
    required this.lateFeeAmount,
    required this.totalPayable,
    required this.ownerName,
    required this.isFirstPayment,
    required this.isHighValuePayment,
    required this.isProcessing,
    required this.onConfirmPay,
  });

  @override
  State<_TenantPaymentTrustFlowSheet> createState() =>
      _TenantPaymentTrustFlowSheetState();
}

class _TenantPaymentTrustFlowSheetState
    extends State<_TenantPaymentTrustFlowSheet> {
  _TrustFlowStep _step = _TrustFlowStep.summary;
  String _activeMessage = '';

  Future<void> _moveToProcessingAndPay() async {
    setState(() {
      _step = _TrustFlowStep.processing;
      _activeMessage = '';
    });

    final result = await widget.onConfirmPay();

    if (!mounted) return;

    setState(() {
      _step = result.isSuccess
          ? _TrustFlowStep.success
          : _TrustFlowStep.failure;
      _activeMessage = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _PremiumGlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(22),
          gradient: _PaymentScreenTheme.heroGradient(context),
          glowColor: _PaymentScreenTheme.brand(context).withValues(alpha: 0.12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _buildCurrentStep(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_step) {
      case _TrustFlowStep.summary:
        return _buildSummaryStep();
      case _TrustFlowStep.method:
        return _buildMethodStep();
      case _TrustFlowStep.reassurance:
        return _buildReassuranceStep();
      case _TrustFlowStep.processing:
        return _buildProcessingStep();
      case _TrustFlowStep.success:
        return _buildResultStep(isSuccess: true);
      case _TrustFlowStep.failure:
        return _buildResultStep(isSuccess: false);
    }
  }

  Widget _buildSummaryStep() {
    return Column(
      key: const ValueKey<String>('summary'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _flowTitle('Payment Summary', 'Review details before continuing.'),
        const SizedBox(height: 14),
        _summaryLine('Rent amount', _formatCurrency(widget.rentAmount)),
        _summaryLine('Late fee', _formatCurrency(widget.lateFeeAmount)),
        _summaryLine(
          'Paying now',
          _formatCurrency(widget.totalPayable),
          isStrong: true,
        ),
        const SizedBox(height: 12),
        _secureStrip(),
        const SizedBox(height: 14),
        _sheetActionButton(
          label: 'Continue',
          onPressed: () => setState(() => _step = _TrustFlowStep.method),
        ),
      ],
    );
  }

  Widget _buildMethodStep() {
    return Column(
      key: const ValueKey<String>('method'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _flowTitle(
          'Choose Payment Method',
          'Powered by Cashfree Secure Checkout.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _PaymentScreenTheme.border(context)),
            color: _PaymentScreenTheme.elevated(
              context,
            ).withValues(alpha: 0.92),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: _PaymentScreenTheme.brand(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'UPI, Card, Netbanking and Wallets',
                  style: TextStyle(
                    color: _PaymentScreenTheme.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _PaymentScreenTheme.success(
                    context,
                  ).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Secure',
                  style: TextStyle(
                    color: _PaymentScreenTheme.textPrimary(context),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _sheetOutlineButton(
                label: 'Back',
                onPressed: () => setState(() => _step = _TrustFlowStep.summary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sheetActionButton(
                label: 'Continue',
                onPressed: () =>
                    setState(() => _step = _TrustFlowStep.reassurance),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReassuranceStep() {
    final trustNotes = <String>[
      'SSL encrypted checkout with secure gateway verification.',
      'Your payment is confirmed only after server-side verification.',
      if (widget.isFirstPayment)
        'This is your first payment. We will guide you through each step.',
      if (widget.isHighValuePayment)
        'High-value payment detected. Please verify amount before proceeding.',
    ];

    return Column(
      key: const ValueKey<String>('reassurance'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _flowTitle('You Are Protected', 'Secure handoff to payment partner.'),
        const SizedBox(height: 12),
        for (final note in trustNotes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.successGreen,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note,
                    style: TextStyle(
                      color: _PaymentScreenTheme.textSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _sheetOutlineButton(
                label: 'Back',
                onPressed: () => setState(() => _step = _TrustFlowStep.method),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sheetActionButton(
                label: 'Pay ${_formatCurrency(widget.totalPayable)}',
                onPressed: widget.isProcessing ? null : _moveToProcessingAndPay,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingStep() {
    return Column(
      key: const ValueKey<String>('processing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        CircularProgressIndicator(color: _PaymentScreenTheme.brand(context)),
        const SizedBox(height: 14),
        Text(
          'Processing your payment securely...',
          style: TextStyle(
            color: _PaymentScreenTheme.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Please do not close this screen.',
          style: TextStyle(color: _PaymentScreenTheme.textSecondary(context)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResultStep({required bool isSuccess}) {
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final color = isSuccess
        ? _PaymentScreenTheme.success(context)
        : _PaymentScreenTheme.error(context);
    final title = isSuccess ? 'Payment Successful' : 'Payment Failed';

    return Column(
      key: ValueKey<String>(isSuccess ? 'success' : 'failure'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 48),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: _PaymentScreenTheme.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _activeMessage,
          style: TextStyle(color: _PaymentScreenTheme.textSecondary(context)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        _sheetActionButton(
          label: isSuccess ? 'Done' : 'Try Again',
          onPressed: () {
            if (isSuccess) {
              Navigator.of(
                context,
              ).pop(_TrustFlowResult(isSuccess: true, message: _activeMessage));
              return;
            }
            setState(() => _step = _TrustFlowStep.summary);
          },
        ),
        if (!isSuccess) ...[
          const SizedBox(height: 10),
          _sheetOutlineButton(
            label: 'Close',
            onPressed: () => Navigator.of(
              context,
            ).pop(_TrustFlowResult(isSuccess: false, message: _activeMessage)),
          ),
        ],
      ],
    );
  }

  Widget _flowTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _PaymentScreenTheme.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: _PaymentScreenTheme.textSecondary(context)),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, String value, {bool isStrong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _PaymentScreenTheme.textSecondary(context),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontWeight: isStrong ? FontWeight.w800 : FontWeight.w600,
              fontSize: isStrong ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secureStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _PaymentScreenTheme.success(context).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _PaymentScreenTheme.success(context).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_outlined,
            size: 16,
            color: _PaymentScreenTheme.success(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'PCI-DSS compliant payment processing',
              style: TextStyle(color: _PaymentScreenTheme.textPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetActionButton({required String label, VoidCallback? onPressed}) {
    return _LockGlowButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sheetOutlineButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _PaymentScreenTheme.border(context)),
        foregroundColor: _PaymentScreenTheme.textPrimary(context),
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(label),
    );
  }
}

class _QrContainer extends StatelessWidget {
  final String Function() amountTextProvider;
  final String Function({required int amount}) buildUpiUri;
  final Animation<double> glowAnimation;

  const _QrContainer({
    required this.amountTextProvider,
    required this.buildUpiUri,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        final alpha = 0.25 + (glowAnimation.value * 0.2);
        final brand = _PaymentScreenTheme.brand(context);
        return Container(
          width: 176,
          height: 176,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: brand.withValues(alpha: alpha),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 6,
                top: 6,
                child: Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AppColors.cFF0B1220.withValues(alpha: 0.15),
                ),
              ),
              Center(
                child: Builder(
                  builder: (context) {
                    final amount = int.tryParse(amountTextProvider()) ?? 0;
                    final upiUri = buildUpiUri(amount: amount);
                    if (upiUri.isEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            color: AppColors.cFF0F172A,
                            size: 52,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'UPI not set',
                            style: TextStyle(
                              color: AppColors.black.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    }

                    return QrImageView(
                      data: upiUri,
                      version: QrVersions.auto,
                      size: 140,
                      backgroundColor: AppColors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppTheme.nearBlack,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppTheme.nearBlack,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DarkDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DarkDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _PaymentScreenTheme.textPrimary(context);
    final hintColor = _PaymentScreenTheme.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _PaymentScreenTheme.elevated(context).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _PaymentScreenTheme.border(context)),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: TextStyle(color: hintColor)),
        iconEnabledColor: textColor,
        dropdownColor: _PaymentScreenTheme.surface(context),
        underline: const SizedBox.shrink(),
        style: TextStyle(color: textColor),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? tone;

  const _DetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = tone ?? _PaymentScreenTheme.textPrimary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _PaymentScreenTheme.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                fontSize: highlight ? 18 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCurrency(int amount) {
  return '\u20B9${_currencyFormatter.format(amount)}';
}

String _formatDate(DateTime date) {
  final months = [
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

final NumberFormat _currencyFormatter = NumberFormat('#,##,##0', 'en_IN');

class TenantRazorpayGatewayAdapter implements PaymentGateway {
  final RazorpayService razorpayService;
  TenantRazorpayGatewayAdapter(this.razorpayService);

  @override
  Future<PaymentGatewayResult> initializePayment(
    PaymentGatewayRequest request,
  ) async {
    try {
      // Use the RazorpayService to initiate payment
      final success = await razorpayService.initiatePayment(
        paymentRequest: PaymentRequest(
          orderId: request.orderId,
          key: request.gatewayKey,
          amount: request.amount,
          currency: request.currency,
          email: request.tenantEmail,
          phone: request.tenantPhone,
          description: 'Rent payment',
          metadata: {},
        ),
        tenantId: '', // Fill as needed
        propertyId: '', // Fill as needed
      );
      // This is a simplification; in production, listen to streams for result
      return PaymentGatewayResult(isSuccess: success);
    } catch (e) {
      return PaymentGatewayResult(
        isSuccess: false,
        failureReason: e.toString(),
      );
    }
  }

  @override
  Future<void> verifyPayment(Map<String, dynamic> payload) async {}

  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) async {}
}
