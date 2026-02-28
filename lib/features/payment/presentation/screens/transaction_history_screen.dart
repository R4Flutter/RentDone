import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';
import 'package:rentdone/features/payment/presentation/providers/transaction_history_provider.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/payment/presentation/widgets/payment_badge.dart';
import 'package:url_launcher/url_launcher.dart';

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(isTenant ? 'Payments' : 'Transactions'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1220), Color(0xFF0F1C2E), Color(0xFF111C30)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _FintechBackgroundEffects()),
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

                      return Column(
                        children: [
                          if (isTenant)
                            _TenantPaymentHero(
                              latestAmount: suggestedAmount,
                              ownerUpiId: ownerUpiId,
                              ownerName: ownerName,
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
                              color: const Color(0xFF3FE0FF),
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
  const _FintechBackgroundEffects();

  @override
  Widget build(BuildContext context) {
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
                    const Color(0xFF4F7CFF).withValues(alpha: 0.3),
                    const Color(0xFF4F7CFF).withValues(alpha: 0),
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
                    const Color(0xFF7A5CFF).withValues(alpha: 0.24),
                    const Color(0xFF7A5CFF).withValues(alpha: 0),
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

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.018);
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

  const _PremiumGlassCard({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 50,
                offset: const Offset(0, 16),
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
      color: Colors.transparent,
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
              color: Colors.white.withValues(alpha: 0.96),
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
    final scheme = Theme.of(context).colorScheme;
    return _PremiumGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.08),
          const Color(0xFF4F7CFF).withValues(alpha: 0.06),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatCurrency(transaction.amount),
                style: const TextStyle(
                  color: Colors.white,
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
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.74)),
          ),
          const SizedBox(height: 4),
          Text(
            'Transaction ID: ${transaction.transactionId}',
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.74)),
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${_formatDate(transaction.createdAt)}',
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.74)),
          ),
          if (transaction.failureReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Failure: ${transaction.failureReason}',
              style: const TextStyle(color: Color(0xFFFF5A5F)),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                showModalBottomSheet(
                  backgroundColor: AppTheme.nearBlack,
                  context: context,
                  builder: (_) =>
                      _TransactionDetailSheet(transaction: transaction),
                );
              },
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
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF4F7CFF), Color(0xFF7A5CFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F7CFF).withValues(alpha: glow),
                    blurRadius: 24,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: _PremiumGlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.1),
              const Color(0xFF4F7CFF).withValues(alpha: 0.06),
            ],
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
                      color: const Color(0xFF22C55E).withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Transaction Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
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
                  tone: const Color(0xFFFF5A5F),
                ),
              const SizedBox(height: 10),
              _LockGlowButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
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
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Center(
          child: Text(
            'No more transactions',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: _PremiumGlassCard(
        borderRadius: BorderRadius.circular(14),
        onTap: onLoadMore,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Center(
          child: Text(
            'Load more',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isOffline ? Icons.wifi_off : Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _TenantPaymentHero extends StatefulWidget {
  final int latestAmount;
  final String ownerUpiId;
  final String ownerName;

  const _TenantPaymentHero({
    required this.latestAmount,
    required this.ownerUpiId,
    required this.ownerName,
  });

  @override
  State<_TenantPaymentHero> createState() => _TenantPaymentHeroState();
}

class _TenantPaymentHeroState extends State<_TenantPaymentHero>
    with TickerProviderStateMixin {
  late final TextEditingController _amountController;
  bool _isLaunchingUpi = false;
  late final AnimationController _introController;
  late final AnimationController _qrGlowController;
  late final FocusNode _amountFocusNode;
  bool _amountFocused = false;

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

  @override
  Widget build(BuildContext context) {
    final latestAmount = widget.latestAmount;
    final enteredAmount =
        int.tryParse(_amountController.text.trim()) ?? latestAmount;

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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B2E4D), Color(0xFF162640), Color(0xFF141F35)],
            ),
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
                        color: const Color(0xFF4F7CFF).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Text(
                        'RENTDONE UPI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Secure',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Scan & Pay Rent',
                    style: TextStyle(
                      color: Colors.white,
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
                    border: Border.all(
                      color: _amountFocused
                          ? const Color(0xFF3FE0FF)
                          : Colors.white.withValues(alpha: 0.13),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                    boxShadow: [
                      if (_amountFocused)
                        BoxShadow(
                          color: const Color(0xFF3FE0FF).withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            color: Colors.white,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            hintText: latestAmount > 0
                                ? latestAmount.toString()
                                : '0',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
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
                        style: const TextStyle(
                          color: Colors.white,
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
                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Encrypted',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
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
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      const SizedBox(width: 8),
                      Text(
                        _isLaunchingUpi
                            ? 'Opening payment app...'
                            : 'Pay with UPI (${_formatCurrency(enteredAmount)})',
                        style: const TextStyle(
                          color: Colors.white,
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
      ),
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
        return Container(
          width: 176,
          height: 176,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F7CFF).withValues(alpha: alpha),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
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
                  color: const Color(0xFF0B1220).withValues(alpha: 0.15),
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
                            color: Color(0xFF0F172A),
                            size: 52,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'UPI not set',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.75),
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
                      backgroundColor: Colors.white,
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
    final textColor = Colors.white.withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(
          hint,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
        ),
        iconEnabledColor: textColor,
        dropdownColor: AppTheme.nearBlack,
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
    final valueColor = tone ?? Colors.white.withValues(alpha: 0.9);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
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
  return 'Rs ${amount.toString()}';
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
