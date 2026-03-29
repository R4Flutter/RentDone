// ignore_for_file: unused_element

import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/providers/tenant_payment_history_provider.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/add_payment_form.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/payment_history_card.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentdone/features/payment/data/gateways/tenant_razorpay_gateway_adapter.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  final TransactionActor actor;
  final String? actorId;
  final bool showTenantPaymentsHome;

  const TransactionHistoryScreen({
    super.key,
    this.actor = TransactionActor.tenant,
    this.actorId,
    this.showTenantPaymentsHome = false,
  });

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  String _normalizePropertyName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String?> _resolveOwnerPropertyIdByName({
    required String ownerId,
    required String propertyName,
  }) async {
    final target = _normalizePropertyName(propertyName);
    if (target.isEmpty) {
      return null;
    }

    final exactMatch = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .where('name', isEqualTo: propertyName.trim())
        .limit(1)
        .get();
    if (exactMatch.docs.isNotEmpty) {
      return exactMatch.docs.first.id;
    }

    final allOwnerProperties = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    for (final doc in allOwnerProperties.docs) {
      final name = (doc.data()['name'] as String? ?? '').trim();
      if (_normalizePropertyName(name) == target) {
        return doc.id;
      }
    }

    return null;
  }

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
    final showTenantPaymentsHome = widget.showTenantPaymentsHome;

    return Scaffold(
      backgroundColor: AppColors.transparent,
      appBar: showTenantPaymentsHome
          ? null
          : AppBar(
              backgroundColor: AppColors.transparent,
              elevation: 0,
              surfaceTintColor: AppColors.transparent,
              foregroundColor: _PaymentScreenTheme.textPrimary(context),
              leading: _buildPremiumBackButton(context),
              leadingWidth: 56,
              title: Text(
                widget.actor == TransactionActor.tenant
                    ? 'Tenant Payment History'
                    : 'Transactions',
                style: TextStyle(
                  color: _PaymentScreenTheme.textPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      floatingActionButton:
          (!showTenantPaymentsHome && widget.actor == TransactionActor.tenant)
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 6,
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _showManualAddPaymentSheet(data),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Payment'),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            if (showTenantPaymentsHome)
              _buildTenantPaymentsHome(context, state, data)
            else
              _buildHistoryOnlyView(context, state, data),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBackButton(BuildContext context) {
    final isDark = _PaymentScreenTheme.isDark(context);
    final textPrimary = _PaymentScreenTheme.textPrimary(context);

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.pop(),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _PaymentScreenTheme.elevated(
                context,
              ).withValues(alpha: isDark ? 0.92 : 0.98),
              border: Border.all(color: _PaymentScreenTheme.border(context)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(
                    alpha: isDark ? 0.22 : 0.08,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryOnlyView(
    BuildContext context,
    AsyncValue<TransactionHistoryState> state,
    TransactionHistoryState data,
  ) {
    if (widget.actor == TransactionActor.tenant) {
      return _buildTenantOwnerStyleHistory(context, state, data);
    }

    final showBlockingError = state.hasError && data.transactions.isEmpty;
    final showInitialLoader = state.isLoading && data.transactions.isEmpty;

    if (showBlockingError) {
      return _HistoryError(
        error: state.error ?? 'Unable to load transactions',
        onRetry: () => ref
            .read(transactionHistoryProvider.notifier)
            .loadInitial(
              actor: widget.actor,
              actorId: widget.actorId,
              force: true,
            ),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        children: [
          _FilterBar(
            actor: widget.actor,
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
                await ref.read(transactionHistoryProvider.notifier).refresh();
              },
              child: showInitialLoader
                  ? const _TransactionListSkeleton()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      itemBuilder: (context, index) {
                        if (index == data.transactions.length) {
                          return _LoadMoreTile(
                            hasMore: data.hasMore,
                            isLoadingMore: data.isLoadingMore,
                            onLoadMore: () => ref
                                .read(transactionHistoryProvider.notifier)
                                .loadMore(),
                          );
                        }

                        final tx = data.transactions[index];
                        return _TransactionTile(transaction: tx);
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemCount: data.transactions.length + 1,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantOwnerStyleHistory(
    BuildContext context,
    AsyncValue<TransactionHistoryState> state,
    TransactionHistoryState data,
  ) {
    final summary = ref.watch(tenantDashboardProvider).asData?.value;
    final showBlockingError = state.hasError && data.transactions.isEmpty;
    final showInitialLoader = state.isLoading && data.transactions.isEmpty;

    if (showBlockingError) {
      return _HistoryError(
        error: state.error ?? 'Unable to load transactions',
        onRetry: () => ref
            .read(transactionHistoryProvider.notifier)
            .loadInitial(
              actor: widget.actor,
              actorId: widget.actorId,
              force: true,
            ),
      );
    }

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        color: _PaymentScreenTheme.brand(context),
        onRefresh: () async {
          await ref.read(transactionHistoryProvider.notifier).refresh();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 120 &&
                data.hasMore &&
                !data.isLoadingMore) {
              ref.read(transactionHistoryProvider.notifier).loadMore();
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
            children: [
              if (summary != null)
                _TenantHistorySummaryCard(
                  tenantName: summary.tenantName,
                  propertyName: summary.propertyName,
                  roomNumber: summary.roomNumber,
                  rentAmount: summary.monthlyRent,
                  phone: summary.tenantPhone,
                ),
              const SizedBox(height: 16),
              if (showInitialLoader)
                const Center(child: CircularProgressIndicator())
              else if (data.transactions.isEmpty)
                const _TransactionEmptyState()
              else
                ..._buildGroupedTenantPayments(data.transactions),
              if (data.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedTenantPayments(List<TransactionRecord> records) {
    final grouped = <DateTime, List<TransactionRecord>>{};

    for (final record in records) {
      final effectiveDate = record.completedAt ?? record.createdAt;
      final key = DateTime(effectiveDate.year, effectiveDate.month);
      grouped.putIfAbsent(key, () => <TransactionRecord>[]).add(record);
    }

    final monthKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final key in monthKeys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            DateFormat('MMMM yyyy').format(key),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _PaymentScreenTheme.textPrimary(context),
            ),
          ),
        ),
      );

      final monthRecords = grouped[key]!
        ..sort((a, b) {
          final aDate = a.completedAt ?? a.createdAt;
          final bDate = b.completedAt ?? b.createdAt;
          return bDate.compareTo(aDate);
        });

      for (final record in monthRecords) {
        widgets.add(
          PaymentHistoryCard(
            payment: _toTenantPaymentRecord(record),
            readOnly: true,
          ),
        );
        widgets.add(const SizedBox(height: 10));
      }
    }

    return widgets;
  }

  Future<void> _showManualAddPaymentSheet(TransactionHistoryState data) async {
    final messenger = ScaffoldMessenger.of(context);
    final tenantId =
        (widget.actorId ?? FirebaseAuth.instance.currentUser?.uid ?? '').trim();

    if (tenantId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to identify tenant for payment.')),
      );
      return;
    }

    try {
      final tenantDoc = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (!tenantDoc.exists) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Tenant details not found.')),
        );
        return;
      }

      final tenantData = tenantDoc.data() ?? <String, dynamic>{};
      final ownerId = (tenantData['ownerId'] as String? ?? '').trim();
      final tenantPropertyName = (tenantData['propertyName'] as String? ?? '')
          .trim();

      var propertyId = (tenantData['propertyId'] as String? ?? '').trim();

      if (propertyId.isEmpty && ownerId.isNotEmpty) {
        final preferredName = tenantPropertyName;

        if (preferredName.isNotEmpty) {
          final resolved = await _resolveOwnerPropertyIdByName(
            ownerId: ownerId,
            propertyName: preferredName,
          );
          if (resolved != null && resolved.isNotEmpty) {
            propertyId = resolved;
          }
        }

        if (propertyId.isEmpty) {
          final ownerProperties = await FirebaseFirestore.instance
              .collection('properties')
              .where('ownerId', isEqualTo: ownerId)
              .limit(2)
              .get();
          if (ownerProperties.docs.length == 1) {
            propertyId = ownerProperties.docs.first.id;
          }
        }
      }

      if (propertyId.isEmpty) {
        final linkedToOwner = ownerId.isNotEmpty;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              linkedToOwner
                  ? 'Owner property match not found. Ensure tenant property name matches owner property name.'
                  : 'Tenant is not linked to an owner property yet. Owner must assign this tenant first.',
            ),
          ),
        );
        return;
      }

      final backendRent = (tenantData['rentAmount'] as num?)?.toInt() ?? 0;
      final fallbackAmount = data.transactions.isEmpty
          ? 0
          : data.transactions.first.amount;
      final rentAmount = backendRent > 0 ? backendRent : fallbackAmount;

      final existingPayments = data.transactions
          .map(_toTenantPaymentRecord)
          .toList();

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return AddPaymentForm(
            rentAmount: rentAmount,
            existingPayments: existingPayments,
            onSubmit: (payload) async {
              final service = ref.read(tenantPaymentHistoryServiceProvider);
              await service.addPayment(
                tenantId: tenantId,
                propertyId: propertyId,
                amount: payload.baseAmount,
                date: payload.date,
                method: payload.method,
                status: payload.status,
                baseAmount: payload.baseAmount,
                paidAmount: payload.paidAmount,
                remainingAmount: payload.remainingAmount,
                notes: payload.notes,
              );

              await ref.read(transactionHistoryProvider.notifier).refresh();
              await ref.read(paymentDashboardProvider.notifier).refreshDue();
            },
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to save payment right now. Please try again.'),
        ),
      );
    }
  }

  Widget _buildTenantPaymentsHome(
    BuildContext context,
    AsyncValue<TransactionHistoryState> state,
    TransactionHistoryState data,
  ) {
    final summaryAsync = ref.watch(tenantDashboardProvider);
    final paymentStateAsync = ref.watch(paymentDashboardProvider);
    final paymentState = paymentStateAsync.asData?.value;
    final due = paymentState?.due;
    final summary = summaryAsync.asData?.value;
    final showInitialLoader = state.isLoading && data.transactions.isEmpty;
    final showHistoryError = state.hasError && data.transactions.isEmpty;
    final latestAmount = data.transactions.isEmpty
        ? 0
        : data.transactions.first.amount;

    final int suggestedAmount =
        due?.monthlyRent ??
        summaryAsync.maybeWhen(
          data: (resolvedSummary) {
            if (resolvedSummary.dueAmount > 0) {
              return resolvedSummary.dueAmount;
            }
            if (resolvedSummary.monthlyRent > 0) {
              return resolvedSummary.monthlyRent;
            }
            return latestAmount;
          },
          orElse: () => latestAmount,
        );

    final tenantId = summary?.tenantId ?? '';
    final ownerDetailsAsync = tenantId.isEmpty
        ? const AsyncValue<TenantOwnerDetails?>.data(null)
        : ref.watch(tenantOwnerDetailsProvider(tenantId));
    final ownerDetails = ownerDetailsAsync.asData?.value;
    final ownerUpiId = (ownerDetails?.ownerUpiId ?? '').trim();
    final ownerName = _firstNonEmpty([
      ownerDetails?.ownerName,
      due?.ownerName,
      summary?.propertyName,
      'Landlord',
    ]);
    final tenantName = _firstNonEmpty([
      summary?.tenantName,
      FirebaseAuth.instance.currentUser?.displayName,
      'Tenant',
    ]);
    final propertyName = _firstNonEmpty([
      due?.propertyName,
      summary?.propertyName,
      'Your property',
    ]);
    final isFirstPayment = !data.transactions.any(
      (tx) => tx.status.toLowerCase() == 'success',
    );

    return SafeArea(
      child: RefreshIndicator(
        color: _PaymentScreenTheme.brand(context),
        onRefresh: () async {
          await Future.wait([
            ref.read(transactionHistoryProvider.notifier).refresh(),
            ref.read(paymentDashboardProvider.notifier).refreshDue(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            _TenantPaymentHero(
              tenantName: tenantName,
              propertyName: propertyName,
              latestAmount: suggestedAmount,
              lateFeeAmount: due?.lateFeeAmount ?? 0,
              totalDueAmount: due?.totalPayable ?? suggestedAmount,
              dueDate: due?.dueDate,
              daysRemaining: due?.daysRemaining,
              paymentReference: due?.paymentId ?? '',
              ownerUpiId: ownerUpiId,
              ownerName: ownerName,
              isFirstPayment: isFirstPayment,
              secureCheckoutReady: due != null,
            ),
            const SizedBox(height: 24),
            _SectionIntro(
              title: 'Recent Payments',
              subtitle:
                  'Track status, receipts, and payment references in one place.',
            ),
            const SizedBox(height: 12),
            _TenantStatusFilterBar(
              selectedStatus: data.selectedStatus,
              onStatusChanged: (status) => ref
                  .read(transactionHistoryProvider.notifier)
                  .setFilters(status: status),
            ),
            const SizedBox(height: 14),
            if (showInitialLoader) ...[
              for (var index = 0; index < 4; index++) ...[
                _PremiumGlassCard(
                  borderRadius: BorderRadius.circular(18),
                  child: const SizedBox(height: 118),
                ),
                if (index < 3) const SizedBox(height: 14),
              ],
            ] else if (showHistoryError) ...[
              _InlineHistoryErrorCard(
                message: 'Recent payments will appear again after refresh.',
                onRetry: () => ref
                    .read(transactionHistoryProvider.notifier)
                    .loadInitial(
                      actor: widget.actor,
                      actorId: widget.actorId,
                      force: true,
                    ),
              ),
            ] else if (data.transactions.isEmpty) ...[
              const _TransactionEmptyState(),
            ] else ...[
              for (
                var index = 0;
                index < data.transactions.length;
                index++
              ) ...[
                _TransactionTile(transaction: data.transactions[index]),
                if (index < data.transactions.length - 1)
                  const SizedBox(height: 14),
              ],
              const SizedBox(height: 18),
              _LoadMoreTile(
                hasMore: data.hasMore,
                isLoadingMore: data.isLoadingMore,
                onLoadMore: () =>
                    ref.read(transactionHistoryProvider.notifier).loadMore(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TenantHistorySummaryCard extends StatelessWidget {
  final String tenantName;
  final String propertyName;
  final String roomNumber;
  final int rentAmount;
  final String phone;

  const _TenantHistorySummaryCard({
    required this.tenantName,
    required this.propertyName,
    required this.roomNumber,
    required this.rentAmount,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tenantName.trim().isEmpty ? 'Tenant' : tenantName.trim(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OwnerDashboardColors.textPrimary(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryPill(
                context,
                'Property: ${propertyName.trim().isEmpty ? 'NA' : propertyName.trim()}',
              ),
              _summaryPill(
                context,
                'Room: ${roomNumber.trim().isEmpty ? 'NA' : roomNumber.trim()}',
              ),
              _summaryPill(context, 'Monthly Rent: Rs $rentAmount'),
              if (phone.trim().isNotEmpty)
                _summaryPill(context, 'Phone: $phone'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: OwnerDashboardColors.brandPrimary(
          context,
        ).withValues(alpha: OwnerDashboardColors.isDark(context) ? 0.10 : 0.06),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: OwnerDashboardColors.textPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PaymentScreenTheme {
  static const Color _lightBrand = Color(0xFF0050D4);
  static const Color _lightBrandStrong = Color(0xFF702AE1);
  static const Color _lightSurface = Color(0xFFF5F7F9);
  static const Color _lightElevated = Color(0xFFEEF1F3);
  static const Color _lightTextPrimary = Color(0xFF2C2F31);
  static const Color _lightTextSecondary = Color(0xFF595C5E);
  static const Color _lightTextMuted = Color(0xFF8A93A4);
  static const Color _lightOutline = Color(0xFFABADAF);
  static const Color _lightSuccess = Color(0xFF00675D);
  static const Color _lightError = Color(0xFFB31B25);

  static bool isDark(BuildContext context) =>
      OwnerDashboardColors.isDark(context);

  static Color brand(BuildContext context) => isDark(context)
      ? OwnerDashboardColors.brandPrimary(context)
      : _lightBrand;

  static Color brandStrong(BuildContext context) => isDark(context)
      ? OwnerDashboardColors.brandPrimaryHover(context)
      : _lightBrandStrong;

  static Color textPrimary(BuildContext context) => isDark(context)
      ? OwnerDashboardColors.textPrimary(context)
      : _lightTextPrimary;

  static Color textSecondary(BuildContext context) => isDark(context)
      ? OwnerDashboardColors.textSecondary(context)
      : _lightTextSecondary;

  static Color textMuted(BuildContext context) => isDark(context)
      ? OwnerDashboardColors.textMuted(context)
      : _lightTextMuted;

  static Color surface(BuildContext context) => isDark(context)
      ? OwnerDashboardColors.cardBackground(context)
      : _lightSurface;

  static Color elevated(BuildContext context) => isDark(context)
      ? OwnerDashboardColors.elevatedBackground(context)
      : _lightElevated;

  static Color border(BuildContext context) => isDark(context)
      ? AppColors.white.withValues(alpha: 0.14)
      : _lightOutline.withValues(alpha: 0.18);

  static Color success(BuildContext context) =>
      isDark(context) ? AppTheme.successGreen : _lightSuccess;

  static Color error(BuildContext context) =>
      isDark(context) ? AppTheme.errorRed : _lightError;

  static Color noise(BuildContext context) => isDark(context)
      ? AppColors.white.withValues(alpha: 0.018)
      : AppColors.black.withValues(alpha: 0.018);

  static LinearGradient pageGradient(BuildContext context) {
    if (isDark(context)) {
      return OwnerDashboardColors.ownerPageBackgroundGradient(context);
    }

    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF8FAFC), Color(0xFFF5F7F9), Color(0xFFF3F6FB)],
    );
  }

  static LinearGradient ctaGradient(BuildContext context) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brand(context), brandStrong(context)],
  );

  static LinearGradient surfaceGradient(BuildContext context, {Color? accent}) {
    final isDarkMode = isDark(context);
    final resolvedAccent = accent ?? brand(context);

    if (isDarkMode) {
      final base = surface(context);
      final elevatedBase = elevated(context);
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(base, AppColors.white, 0.04) ?? base,
          Color.lerp(elevatedBase, resolvedAccent, 0.18) ?? elevatedBase,
        ],
      );
    }

    final top =
        Color.lerp(AppColors.white, resolvedAccent, 0.03) ?? AppColors.white;
    final bottom =
        Color.lerp(const Color(0xFFF7F9FC), resolvedAccent, 0.07) ??
        const Color(0xFFF7F9FC);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [top.withValues(alpha: 0.94), bottom.withValues(alpha: 0.98)],
    );
  }

  static LinearGradient heroGradient(BuildContext context) {
    final isDarkMode = isDark(context);
    if (isDarkMode) {
      final base = surface(context);
      final elevatedBase = elevated(context);
      final brandColor = brand(context);
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(base, AppColors.white, 0.04) ?? base,
          Color.lerp(elevatedBase, brandColor, 0.24) ?? elevatedBase,
          Color.lerp(base, AppColors.black, 0.12) ?? base,
        ],
      );
    }

    final top =
        Color.lerp(AppColors.white, brand(context), 0.05) ?? AppColors.white;
    final middle = Color.lerp(
      const Color(0xFFF5F7FB),
      brandStrong(context),
      0.10,
    )!;
    final bottom = Color.lerp(const Color(0xFFF7F9FD), success(context), 0.05)!;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        top.withValues(alpha: 0.98),
        middle.withValues(alpha: 0.96),
        bottom.withValues(alpha: 0.98),
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
    final topBlobColor = _PaymentScreenTheme.brand(
      context,
    ).withValues(alpha: _PaymentScreenTheme.isDark(context) ? 0.18 : 0.11);
    final middleBlobColor = _PaymentScreenTheme.brandStrong(
      context,
    ).withValues(alpha: _PaymentScreenTheme.isDark(context) ? 0.16 : 0.10);
    final bottomBlobColor = _PaymentScreenTheme.success(
      context,
    ).withValues(alpha: _PaymentScreenTheme.isDark(context) ? 0.14 : 0.08);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            right: -110,
            top: -70,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [topBlobColor, topBlobColor.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Positioned(
            left: -120,
            top: 260,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    middleBlobColor,
                    middleBlobColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -120,
            bottom: -140,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    bottomBlobColor,
                    bottomBlobColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.white.withValues(alpha: 0.0),
                    _PaymentScreenTheme.brandStrong(
                      context,
                    ).withValues(alpha: 0.025),
                    _PaymentScreenTheme.success(
                      context,
                    ).withValues(alpha: 0.01),
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
        ? AppColors.white.withValues(alpha: 0.12)
        : AppColors.white.withValues(alpha: 0.72);
    final ambientShadow = AppColors.black.withValues(
      alpha: isDark ? 0.22 : 0.08,
    );
    final topHighlight = AppColors.white.withValues(
      alpha: isDark ? 0.02 : 0.55,
    );

    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: gradient ?? _PaymentScreenTheme.surfaceGradient(context),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: ambientShadow,
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: topHighlight,
                blurRadius: 18,
                offset: const Offset(-6, -6),
              ),
              if (glowColor != null)
                BoxShadow(
                  color: glowColor!,
                  blurRadius: 28,
                  offset: const Offset(0, 12),
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

class _SectionIntro extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionIntro({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _PaymentScreenTheme.textPrimary(context),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: _PaymentScreenTheme.textSecondary(context),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _TrustIndicatorChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustIndicatorChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _PaymentScreenTheme.elevated(context).withValues(alpha: 0.94),
        border: Border.all(color: _PaymentScreenTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _PaymentScreenTheme.brand(context)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstPaymentBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FirstPaymentBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final success = _PaymentScreenTheme.success(context);
    return _PremiumGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      gradient: _PaymentScreenTheme.surfaceGradient(context, accent: success),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: success.withValues(alpha: 0.16),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _PaymentScreenTheme.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _PaymentScreenTheme.textSecondary(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _PaymentScreenTheme.elevated(context).withValues(alpha: 0.94),
        border: Border.all(color: _PaymentScreenTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _PaymentScreenTheme.brand(context)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialHeaderMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EditorialHeaderMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _PaymentScreenTheme.textSecondary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricGlassTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricGlassTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.white.withValues(alpha: 0.48),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.58)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _PaymentScreenTheme.textSecondary(
                context,
              ).withValues(alpha: 0.86),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _AmountLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
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
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String? trustBadge;
  final bool highlighted;
  final Widget footer;

  const _PaymentOptionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.footer,
    this.trustBadge,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return _PremiumGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      gradient: _PaymentScreenTheme.surfaceGradient(
        context,
        accent: highlighted ? accent : _PaymentScreenTheme.brand(context),
      ),
      glowColor: highlighted ? accent.withValues(alpha: 0.12) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: accent.withValues(alpha: highlighted ? 0.16 : 0.12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _PaymentScreenTheme.textPrimary(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _PaymentScreenTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trustBadge != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: _PaymentScreenTheme.elevated(
                  context,
                ).withValues(alpha: 0.96),
                border: Border.all(color: _PaymentScreenTheme.border(context)),
              ),
              child: Text(
                trustBadge!,
                style: TextStyle(
                  color: _PaymentScreenTheme.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          footer,
        ],
      ),
    );
  }
}

class _SoftDisabledAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftDisabledAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: _PaymentScreenTheme.elevated(context).withValues(alpha: 0.96),
        border: Border.all(color: _PaymentScreenTheme.border(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: _PaymentScreenTheme.textSecondary(context),
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _PaymentScreenTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReassuranceBullet extends StatelessWidget {
  final String text;

  const _ReassuranceBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: _PaymentScreenTheme.success(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _PaymentScreenTheme.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantStatusFilterBar extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const _TenantStatusFilterBar({
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = ['all', 'success', 'pending', 'failed'];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final status = filters[index];
          final selected = selectedStatus == status;
          return GestureDetector(
            onTap: () => onStatusChanged(status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: selected
                    ? _PaymentScreenTheme.ctaGradient(context)
                    : null,
                color: selected
                    ? null
                    : _PaymentScreenTheme.elevated(
                        context,
                      ).withValues(alpha: 0.95),
                border: Border.all(
                  color: selected
                      ? _PaymentScreenTheme.brand(
                          context,
                        ).withValues(alpha: 0.18)
                      : _PaymentScreenTheme.border(context),
                ),
              ),
              child: Text(
                status == 'all'
                    ? 'All'
                    : '${status[0].toUpperCase()}${status.substring(1)}',
                style: TextStyle(
                  color: selected
                      ? AppColors.white
                      : _PaymentScreenTheme.textPrimary(context),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InlineHistoryErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineHistoryErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _PremiumGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent payments will be back shortly',
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: _PaymentScreenTheme.textSecondary(context)),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _PaymentScreenTheme.brand(context),
                foregroundColor: AppColors.white,
              ),
              child: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionEmptyState extends StatelessWidget {
  const _TransactionEmptyState();

  @override
  Widget build(BuildContext context) {
    return _PremiumGlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _PaymentScreenTheme.brand(context).withValues(alpha: 0.10),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: _PaymentScreenTheme.brand(context),
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No payments yet',
            style: TextStyle(
              color: _PaymentScreenTheme.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your payment history will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: _PaymentScreenTheme.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TransactionActor actor;
  final int? selectedYear;
  final String selectedStatus;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<String> onStatusChanged;

  const _FilterBar({
    required this.actor,
    required this.selectedYear,
    required this.selectedStatus,
    required this.onYearChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final years = _yearOptions();
    final statuses = ['all', 'success', 'failed', 'pending', 'refunded'];
    final title = actor == TransactionActor.tenant ? 'History' : 'Transactions';
    final subtitle = actor == TransactionActor.tenant
        ? 'Track your past rental and utility payments'
        : 'Review portfolio payment activity and transaction health';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PremiumGlassCard(
            padding: const EdgeInsets.all(22),
            borderRadius: BorderRadius.circular(28),
            gradient: _PaymentScreenTheme.surfaceGradient(
              context,
              accent: actor == TransactionActor.tenant
                  ? _PaymentScreenTheme.brand(context)
                  : _PaymentScreenTheme.success(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _PaymentScreenTheme.textPrimary(context),
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _PaymentScreenTheme.textSecondary(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
                const SizedBox(width: 10),
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
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TinyMetaPill(
                icon: Icons.auto_graph_rounded,
                label: selectedStatus == 'all'
                    ? 'All activity'
                    : '${selectedStatus[0].toUpperCase()}${selectedStatus.substring(1)} only',
              ),
              _TinyMetaPill(
                icon: Icons.calendar_today_outlined,
                label: selectedYear?.toString() ?? 'All years',
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
    return PaymentHistoryCard(
      payment: _toTenantPaymentRecord(transaction),
      readOnly: true,
    );
  }
}

TenantPaymentRecord _toTenantPaymentRecord(TransactionRecord tx) {
  final normalized = tx.status.trim().toLowerCase();
  final baseAmount = (tx.baseAmount ?? tx.amount).clamp(0, 5000000);
  final paidFromRecord = tx.paidAmount;
  final remainingFromRecord = tx.remainingAmount;

  final int paidAmount;
  final int remaining;
  final String resolvedStatus;

  if (normalized == 'success' || normalized == 'paid') {
    paidAmount = (paidFromRecord ?? baseAmount).clamp(0, baseAmount);
    remaining = 0;
    resolvedStatus = 'paid';
  } else if (normalized == 'partial') {
    final computedPaid =
        (paidFromRecord ?? (baseAmount - (remainingFromRecord ?? 0))).clamp(
          0,
          baseAmount,
        );
    paidAmount = computedPaid;
    remaining = (remainingFromRecord ?? (baseAmount - computedPaid)).clamp(
      0,
      baseAmount,
    );
    resolvedStatus = remaining == 0 ? 'paid' : 'partial';
  } else {
    paidAmount = 0;
    remaining = baseAmount;
    resolvedStatus = 'unpaid';
  }

  return TenantPaymentRecord(
    id: tx.transactionId.isNotEmpty ? tx.transactionId : tx.paymentId,
    tenantId: tx.tenantId,
    propertyId: tx.leaseId,
    amount: baseAmount,
    date: tx.completedAt ?? tx.createdAt,
    method: tx.gateway.toUpperCase(),
    status: resolvedStatus,
    createdAt: tx.createdAt,
    baseAmount: baseAmount,
    paidAmount: paidAmount,
    remainingAmount: remaining,
    transactionId: tx.transactionId,
    notes: tx.failureReason,
    installments: const <PaymentInstallment>[],
  );
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
  final String tenantName;
  final String propertyName;
  final int latestAmount;
  final int lateFeeAmount;
  final int totalDueAmount;
  final DateTime? dueDate;
  final int? daysRemaining;
  final String paymentReference;
  final String ownerUpiId;
  final String ownerName;
  final bool isFirstPayment;
  final bool secureCheckoutReady;

  const _TenantPaymentHero({
    required this.tenantName,
    required this.propertyName,
    required this.latestAmount,
    required this.lateFeeAmount,
    required this.totalDueAmount,
    required this.dueDate,
    this.daysRemaining,
    required this.paymentReference,
    required this.ownerUpiId,
    required this.ownerName,
    required this.isFirstPayment,
    required this.secureCheckoutReady,
  });

  @override
  ConsumerState<_TenantPaymentHero> createState() => _TenantPaymentHeroState();
}

class _TenantPaymentHeroState extends ConsumerState<_TenantPaymentHero>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _amountController;
  bool _isLaunchingUpi = false;
  bool _isPayingRazorpay = false;
  bool _feeBreakdownExpanded = false;
  late final AnimationController _introController;
  late final FocusNode _amountFocusNode;
  bool _amountFocused = false;

  bool get _isHighValuePayment {
    final effectiveTotal = _upiTotalPayable > widget.totalDueAmount
        ? _upiTotalPayable
        : widget.totalDueAmount;
    return effectiveTotal >= 50000;
  }

  int get _enteredRentAmount {
    final parsed = int.tryParse(_amountController.text.trim()) ?? 0;
    if (parsed > 0) {
      return parsed;
    }
    return widget.latestAmount > 0 ? widget.latestAmount : 0;
  }

  int get _lateFeeAmount => widget.lateFeeAmount < 0 ? 0 : widget.lateFeeAmount;

  int get _upiTotalPayable => _enteredRentAmount + _lateFeeAmount;

  bool get _isUpiReady => widget.ownerUpiId.trim().isNotEmpty;

  int? get _resolvedDaysRemaining {
    if (widget.daysRemaining != null) {
      return widget.daysRemaining;
    }
    if (widget.dueDate == null) {
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      widget.dueDate!.year,
      widget.dueDate!.month,
      widget.dueDate!.day,
    );
    return dueDate.difference(today).inDays;
  }

  String get _dueBadgeLabel {
    final days = _resolvedDaysRemaining;
    if (days == null) {
      return 'Syncing due';
    }
    if (days < 0) {
      final overdueDays = days.abs();
      return 'Overdue by $overdueDays ${overdueDays == 1 ? 'day' : 'days'}';
    }
    if (days == 0) {
      return 'Due today';
    }
    if (days == 1) {
      return 'Due tomorrow';
    }
    return 'Due in $days days';
  }

  String get _invoiceReferenceLabel {
    final raw = widget.paymentReference.trim();
    if (raw.isEmpty) {
      return 'Auto-generated';
    }

    final normalized = raw.length > 10 ? raw.substring(0, 10) : raw;
    return '#${normalized.toUpperCase()}';
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

  Future<void> _copyUpiId(BuildContext context) async {
    if (!_isUpiReady) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: widget.ownerUpiId.trim()));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
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
          content: Text('We could not open a UPI app. Try secure checkout.'),
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
        ref.read(paymentDashboardProvider.notifier).refreshDue();
        return const _TrustFlowResult(
          isSuccess: true,
          message: 'Payment successful. Your receipt is being updated.',
        );
      } else {
        final payState = ref.read(paymentDashboardProvider).asData?.value;
        final msg =
            payState?.message ??
            'Payment failed. No money deducted. Try again.';
        return _TrustFlowResult(isSuccess: false, message: msg);
      }
    } on PaymentFailure catch (failure) {
      final cleaned = failure.message.trim();
      return _TrustFlowResult(
        isSuccess: false,
        message: cleaned.isEmpty
            ? 'Payment failed. No money deducted. Try again.'
            : cleaned,
      );
    } catch (error) {
      final raw = error.toString().replaceFirst('Exception: ', '').trim();
      final payState = ref.read(paymentDashboardProvider).asData?.value;
      final fallback = payState?.message?.trim() ?? '';
      return _TrustFlowResult(
        isSuccess: false,
        message: raw.isNotEmpty
            ? raw
            : (fallback.isNotEmpty
                  ? fallback
                  : 'Payment failed. No money deducted. Try again.'),
      );
    } finally {
      if (mounted) setState(() => _isPayingRazorpay = false);
    }
  }

  Future<void> _startRazorpayTrustFlow(BuildContext context) async {
    final due = ref.read(paymentDashboardProvider).asData?.value.due;

    if (due == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secure checkout is preparing your current due.'),
        ),
      );
      return;
    }

    final rentAmount = due.monthlyRent > 0
        ? due.monthlyRent
        : _enteredRentAmount;
    final totalPayable = due.totalPayable > 0
        ? due.totalPayable
        : rentAmount + due.lateFeeAmount;

    final result = await showModalBottomSheet<_TrustFlowResult>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _TenantPaymentTrustFlowSheet(
          rentAmount: rentAmount,
          lateFeeAmount: due.lateFeeAmount,
          totalPayable: totalPayable,
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

  Widget _buildModernPaymentsHome(
    BuildContext context, {
    required int enteredAmount,
    required Color brand,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color success,
    required Color error,
    required Color border,
    required String dueDateLabel,
  }) {
    final isDarkMode = _PaymentScreenTheme.isDark(context);
    final dueSignalColor = switch (_resolvedDaysRemaining) {
      null => brand,
      < 0 => error,
      <= 3 => AppTheme.warningAmber,
      _ => success,
    };
    final shortDueDateLabel = widget.dueDate == null
        ? 'Auto-sync'
        : DateFormat('dd MMM yyyy').format(widget.dueDate!);
    final amountFieldFill = Color.lerp(
      _PaymentScreenTheme.elevated(context),
      brand,
      _amountFocused ? (isDarkMode ? 0.14 : 0.04) : (isDarkMode ? 0.04 : 0.015),
    )!;
    final primaryAction = _isUpiReady
        ? (_isLaunchingUpi || _upiTotalPayable <= 0
              ? null
              : () => _openUpiApp(context, amount: _upiTotalPayable))
        : (widget.secureCheckoutReady && !_isPayingRazorpay
              ? () => _startRazorpayTrustFlow(context)
              : null);
    final primaryBusy = _isUpiReady ? _isLaunchingUpi : _isPayingRazorpay;
    final primaryLabel = _isUpiReady
        ? (primaryBusy ? 'Opening UPI app...' : 'Pay Now')
        : (primaryBusy ? 'Opening secure checkout...' : 'Continue to checkout');
    final primaryCaption = _isUpiReady
        ? 'Direct landlord settlement with your preferred UPI app.'
        : 'Razorpay confirms the latest verified due before you pay.';
    final amountSummaryLabel = _lateFeeAmount > 0
        ? 'Late fee included'
        : widget.isFirstPayment
        ? 'Zero convenience fee'
        : 'No hidden charges';

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _introController, curve: Curves.easeOut),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PremiumGlassCard(
              padding: const EdgeInsets.all(22),
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    AppColors.white,
                    brand,
                    0.02,
                  )!.withValues(alpha: 0.96),
                  Color.lerp(
                    const Color(0xFFF5F7FB),
                    _PaymentScreenTheme.brandStrong(context),
                    0.08,
                  )!.withValues(alpha: 0.94),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payments',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _EditorialHeaderMeta(
                          icon: Icons.location_city_outlined,
                          label: widget.propertyName,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: border.withValues(alpha: 0.7),
                      ),
                      Expanded(
                        child: _EditorialHeaderMeta(
                          icon: Icons.person_outline_rounded,
                          label: widget.ownerName,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _SectionIntro(
              title: 'Pay Rent',
              subtitle:
                  'Friendly fintech payment flow with direct UPI and secure checkout.',
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TrustIndicatorChip(
                  icon: Icons.shield_outlined,
                  label: 'Bank-grade security',
                ),
                _TrustIndicatorChip(
                  icon: Icons.bolt_rounded,
                  label: 'Instant confirmation',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PremiumGlassCard(
              padding: const EdgeInsets.all(22),
              borderRadius: BorderRadius.circular(30),
              gradient: _PaymentScreenTheme.heroGradient(context),
              glowColor: brand.withValues(alpha: 0.10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL AMOUNT DUE',
                              style: TextStyle(
                                color: textSecondary.withValues(alpha: 0.82),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _formatCurrency(widget.totalDueAmount),
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: dueSignalColor.withValues(alpha: 0.10),
                          border: Border.all(
                            color: dueSignalColor.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dueSignalColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _dueBadgeLabel.toUpperCase(),
                              style: TextStyle(
                                color: dueSignalColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricGlassTile(
                          label: 'Due Date',
                          value: shortDueDateLabel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricGlassTile(
                          label: 'Invoice ID',
                          value: _invoiceReferenceLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: amountFieldFill.withValues(
                        alpha: isDarkMode ? 0.84 : 0.76,
                      ),
                      border: Border.all(color: border.withValues(alpha: 0.85)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Amount to send',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: AppColors.white.withValues(alpha: 0.55),
                              ),
                              child: Text(
                                amountSummaryLabel,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountController,
                          focusNode: _amountFocusNode,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.latestAmount > 0
                                ? widget.latestAmount.toString()
                                : '0',
                            hintStyle: TextStyle(
                              color: textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                            prefixText: '\u20B9 ',
                            prefixStyle: TextStyle(
                              color: brand,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                            suffixIcon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: _amountFocused ? brand : textMuted,
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Edit the direct UPI amount here. Secure checkout always confirms the latest verified due.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(
                      () => _feeBreakdownExpanded = !_feeBreakdownExpanded,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _PaymentScreenTheme.elevated(
                          context,
                        ).withValues(alpha: 0.92),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fee breakdown',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Direct UPI total: ${_formatCurrency(_upiTotalPayable)}',
                                  style: TextStyle(color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _feeBreakdownExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    crossFadeState: _feeBreakdownExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(height: 0),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          _AmountLine(
                            label: 'Rent',
                            value: _formatCurrency(enteredAmount),
                          ),
                          if (_lateFeeAmount > 0)
                            _AmountLine(
                              label: 'Late fee',
                              value: _formatCurrency(_lateFeeAmount),
                            ),
                          const _AmountLine(
                            label: 'Convenience fee',
                            value: '\u20B90',
                          ),
                          const SizedBox(height: 6),
                          _AmountLine(
                            label: 'Total',
                            value: _formatCurrency(_upiTotalPayable),
                            highlight: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (primaryAction != null)
                    _LockGlowButton(
                      onPressed: primaryAction,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (primaryBusy)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          else
                            Icon(
                              _isUpiReady
                                  ? Icons.arrow_forward_rounded
                                  : Icons.lock_outline_rounded,
                              color: AppColors.white,
                              size: 19,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isUpiReady
                                ? '$primaryLabel ${_formatCurrency(_upiTotalPayable)}'
                                : primaryLabel,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const _SoftDisabledAction(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Preparing payment options',
                    ),
                  const SizedBox(height: 10),
                  Text(
                    primaryCaption,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _TinyMetaPill(
                        icon: Icons.person_outline_rounded,
                        label: widget.tenantName,
                      ),
                      _TinyMetaPill(
                        icon: Icons.event_outlined,
                        label: dueDateLabel,
                      ),
                      const _TinyMetaPill(
                        icon: Icons.receipt_long_outlined,
                        label: 'Instant receipt',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.isFirstPayment) ...[
              const SizedBox(height: 14),
              const _FirstPaymentBanner(
                title: 'Zero convenience fee on your first UPI payment',
                subtitle:
                    'A clean first payment with direct landlord settlement and instant digital proof.',
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Paying To',
              style: TextStyle(
                color: textSecondary.withValues(alpha: 0.86),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            _PremiumGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: brand.withValues(alpha: 0.10),
                    ),
                    child: Icon(
                      Icons.account_balance_outlined,
                      color: brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isUpiReady ? 'UPI ID' : 'Secure settlement',
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.86),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isUpiReady
                              ? widget.ownerUpiId
                              : 'Landlord UPI will appear here once setup is complete.',
                          style: TextStyle(
                            color: _isUpiReady ? textPrimary : textSecondary,
                            fontWeight: _isUpiReady
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isUpiReady)
                    IconButton(
                      onPressed: () => _copyUpiId(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.white.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      icon: Icon(Icons.copy_rounded, color: brand, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Method',
              style: TextStyle(
                color: textSecondary.withValues(alpha: 0.86),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _PaymentOptionCard(
              icon: Icons.qr_code_rounded,
              accent: brand,
              title: 'Pay via UPI',
              subtitle: _isUpiReady
                  ? 'Fastest, no extra steps'
                  : 'UPI setup required, secure checkout is ready',
              statusLabel: _isUpiReady ? 'Available' : 'Setup required',
              highlighted: true,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isUpiReady
                        ? widget.ownerUpiId
                        : 'Ask your landlord to add a UPI ID, or continue with secure checkout below.',
                    style: TextStyle(
                      color: _isUpiReady ? textPrimary : textSecondary,
                      fontWeight: _isUpiReady
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isUpiReady)
                    _LockGlowButton(
                      onPressed: _isLaunchingUpi || _upiTotalPayable <= 0
                          ? null
                          : () =>
                                _openUpiApp(context, amount: _upiTotalPayable),
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
                                ? 'Opening UPI app...'
                                : 'Open UPI for ${_formatCurrency(_upiTotalPayable)}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const _SoftDisabledAction(
                      icon: Icons.info_outline_rounded,
                      label: 'Temporarily unavailable. Try secure checkout',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PaymentOptionCard(
              icon: Icons.account_balance_wallet_outlined,
              accent: success,
              title: 'Cards / NetBanking',
              subtitle: 'Secure via Razorpay',
              statusLabel: widget.secureCheckoutReady ? 'Available' : 'Syncing',
              trustBadge: 'Powered by Razorpay',
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.secureCheckoutReady
                        ? 'Final amount is confirmed securely at checkout before you pay.'
                        : 'We are syncing your live due so secure checkout stays accurate.',
                    style: TextStyle(color: textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (widget.secureCheckoutReady)
                    _RazorpayPayButton(
                      isLoading: _isPayingRazorpay,
                      label: 'Secure checkout',
                      onPressed: () => _startRazorpayTrustFlow(context),
                    )
                  else
                    const _SoftDisabledAction(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Secure checkout will be ready in a moment',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _PremiumGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              gradient: _PaymentScreenTheme.surfaceGradient(
                context,
                accent: success,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why tenants trust this flow',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ReassuranceBullet(
                    text: 'Money goes directly to the landlord',
                  ),
                  const _ReassuranceBullet(
                    text: 'Instant digital receipt and transaction trail',
                  ),
                  const _ReassuranceBullet(text: 'No hidden charges'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: success.withValues(alpha: 0.14),
                      border: Border.all(
                        color: success.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your payment history and verification stay synced with RentDone and Firebase.',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isHighValuePayment) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: error.withValues(alpha: 0.10),
                        border: Border.all(
                          color: error.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.priority_high_rounded,
                            color: error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'High-value payment detected. Recheck the amount before you continue.',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enteredAmount = _enteredRentAmount;
    final brand = _PaymentScreenTheme.brand(context);
    final textPrimary = _PaymentScreenTheme.textPrimary(context);
    final textSecondary = _PaymentScreenTheme.textSecondary(context);
    final textMuted = _PaymentScreenTheme.textMuted(context);
    final success = _PaymentScreenTheme.success(context);
    final error = _PaymentScreenTheme.error(context);
    final border = _PaymentScreenTheme.border(context);
    final dueDateLabel = widget.dueDate == null
        ? 'Due date updates automatically'
        : 'Due ${DateFormat('dd MMM yyyy').format(widget.dueDate!)}';

    return _buildModernPaymentsHome(
      context,
      enteredAmount: enteredAmount,
      brand: brand,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      success: success,
      error: error,
      border: border,
      dueDateLabel: dueDateLabel,
    );
  }
}

class _RazorpayPayButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;

  const _RazorpayPayButton({
    required this.isLoading,
    required this.onPressed,
    this.label = 'Pay securely',
  });

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
                  size: 20,
                ),
              const SizedBox(width: 10),
              Text(
                isLoading ? 'Processing...' : label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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
          'Powered by Razorpay Secure Checkout.',
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
                  'UPI, cards, net banking, and wallets',
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
        const SizedBox(height: 6),
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _PaymentScreenTheme.brand(
                        context,
                      ).withValues(alpha: 0.08),
                      _PaymentScreenTheme.brand(
                        context,
                      ).withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 108,
                height: 108,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _PaymentScreenTheme.brand(context),
                  backgroundColor: _PaymentScreenTheme.brand(
                    context,
                  ).withValues(alpha: 0.10),
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.34),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.58),
                  ),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: _PaymentScreenTheme.brand(context),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Processing Payment...',
          style: TextStyle(
            color: _PaymentScreenTheme.textPrimary(context),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'This should only take a moment. Please do not refresh.',
          style: TextStyle(
            color: _PaymentScreenTheme.textSecondary(context),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        _PremiumGlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(24),
          gradient: _PaymentScreenTheme.surfaceGradient(
            context,
            accent: _PaymentScreenTheme.brand(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AMOUNT',
                style: TextStyle(
                  color: _PaymentScreenTheme.textSecondary(
                    context,
                  ).withValues(alpha: 0.82),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatCurrency(widget.totalPayable),
                style: TextStyle(
                  color: _PaymentScreenTheme.textPrimary(context),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Merchant', value: widget.ownerName),
              const _DetailRow(
                label: 'Payment Method',
                value: 'Secure checkout',
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        color: _PaymentScreenTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _PaymentScreenTheme.success(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Authorizing',
                      style: TextStyle(
                        color: _PaymentScreenTheme.success(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: 0.44),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 42),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            color: _PaymentScreenTheme.textPrimary(context),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _activeMessage.isEmpty
              ? (isSuccess
                    ? 'Your payment is confirmed and syncing to history.'
                    : 'Your transaction could not be processed.')
              : _activeMessage,
          style: TextStyle(
            color: _PaymentScreenTheme.textSecondary(context),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: color.withValues(alpha: isSuccess ? 0.10 : 0.08),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: isSuccess
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified summary',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DetailRow(
                      label: 'Amount',
                      value: _formatCurrency(widget.totalPayable),
                      highlight: true,
                    ),
                    _DetailRow(label: 'Merchant', value: widget.ownerName),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Declined reason',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _activeMessage.isEmpty
                                ? 'Please retry with the same or another payment method.'
                                : _activeMessage,
                            style: TextStyle(
                              color: _PaymentScreenTheme.textPrimary(context),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _sheetActionButton(
          label: isSuccess ? 'Done' : 'Retry Payment',
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

Color _statusTone(BuildContext context, String status) {
  switch (status.toLowerCase()) {
    case 'success':
    case 'paid':
      return _PaymentScreenTheme.success(context);
    case 'pending':
      return AppTheme.warningAmber;
    case 'failed':
      return _PaymentScreenTheme.error(context);
    default:
      return _PaymentScreenTheme.brand(context);
  }
}

IconData _transactionLeadingIcon(TransactionRecord transaction) {
  switch (transaction.gateway.toLowerCase()) {
    case 'upi':
      return Icons.qr_code_rounded;
    case 'razorpay':
      return Icons.credit_card_rounded;
    default:
      return transaction.status.toLowerCase() == 'failed'
          ? Icons.error_outline_rounded
          : Icons.home_work_rounded;
  }
}

String _transactionTitle(TransactionRecord transaction) {
  final monthLabel = DateFormat('MMM').format(transaction.createdAt);
  return 'Monthly Rent - $monthLabel';
}

String _gatewayLabel(String gateway) {
  switch (gateway.toLowerCase()) {
    case 'razorpay':
      return 'Razorpay';
    case 'upi':
      return 'UPI';
    default:
      return gateway.isEmpty ? 'Payment' : gateway.toUpperCase();
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

String _formatTimelineDate(DateTime date) =>
    DateFormat('dd MMM yyyy').format(date);

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = (value ?? '').trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

final NumberFormat _currencyFormatter = NumberFormat('#,##,##0', 'en_IN');
