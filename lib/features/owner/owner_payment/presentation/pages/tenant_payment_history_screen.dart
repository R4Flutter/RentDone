import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/providers/tenant_payment_history_provider.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/add_payment_form.dart';
import 'package:rentdone/features/owner/owner_payment/presentation/widgets/payment_history_card.dart';
import 'package:rentdone/shared/widgets/back_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TenantPaymentHistoryScreen extends ConsumerStatefulWidget {
  const TenantPaymentHistoryScreen({
    super.key,
    required this.propertyId,
    required this.tenantId,
    this.propertyName,
    this.tenantName,
    this.roomNumber,
    this.rentAmount,
    this.phone,
  });

  final String propertyId;
  final String tenantId;
  final String? propertyName;
  final String? tenantName;
  final String? roomNumber;
  final int? rentAmount;
  final String? phone;

  @override
  ConsumerState<TenantPaymentHistoryScreen> createState() =>
      _TenantPaymentHistoryScreenState();
}

class _TenantPaymentHistoryScreenState
    extends ConsumerState<TenantPaymentHistoryScreen> {
  static const int _pageSize = 20;

  String _normalizePropertyName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String?> _findOwnerPropertyIdByName({
    required String ownerId,
    required String propertyName,
  }) async {
    final normalizedTarget = _normalizePropertyName(propertyName);
    if (normalizedTarget.isEmpty) {
      return null;
    }

    final exact = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .where('name', isEqualTo: propertyName.trim())
        .limit(1)
        .get();
    if (exact.docs.isNotEmpty) {
      return exact.docs.first.id;
    }

    final ownerProperties = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    for (final doc in ownerProperties.docs) {
      final candidateName = (doc.data()['name'] as String? ?? '').trim();
      if (_normalizePropertyName(candidateName) == normalizedTarget) {
        return doc.id;
      }
    }

    return null;
  }

  final List<TenantPaymentRecord> _items = <TenantPaymentRecord>[];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _loadMoreError;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _loadMoreError = null;
      _hasMore = true;
      _cursor = null;
    });

    try {
      final service = ref.read(tenantPaymentHistoryServiceProvider);
      final page = await service.fetchTenantPayments(
        tenantId: widget.tenantId,
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load payment history. Pull to retry.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final service = ref.read(tenantPaymentHistoryServiceProvider);
      final page = await service.fetchTenantPayments(
        tenantId: widget.tenantId,
        limit: _pageSize,
        cursor: _cursor,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = 'Unable to load more payments. Try again.';
      });
    }
  }

  Future<void> _addPayment(AddPaymentPayload payload) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(tenantPaymentHistoryServiceProvider);
    var propertyId = widget.propertyId.trim();
    final ownerId = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    var tenantOwnerId = '';
    var tenantPropertyId = '';
    var tenantPropertyName = '';

    if (propertyId.isEmpty || ownerId.isNotEmpty) {
      try {
        final tenantDoc = await FirebaseFirestore.instance
            .collection('tenants')
            .doc(widget.tenantId)
            .get();
        if (tenantDoc.exists) {
          final tenantData = tenantDoc.data() ?? <String, dynamic>{};
          tenantOwnerId = (tenantData['ownerId'] as String? ?? '').trim();
          tenantPropertyId = (tenantData['propertyId'] as String? ?? '').trim();
          tenantPropertyName =
              (tenantData['propertyName'] as String? ?? '').trim();

          if (propertyId.isEmpty && tenantPropertyId.isNotEmpty) {
            propertyId = tenantPropertyId;
          }
        }
      } catch (_) {
        // fall through to error message below
      }
    }

    final ownerPropertyName = (widget.propertyName ?? '').trim();
    final tenantIsLinkedToOwnerApp =
        tenantOwnerId.isNotEmpty || tenantPropertyId.isNotEmpty;

    if (propertyId.isEmpty && ownerId.isNotEmpty && ownerPropertyName.isNotEmpty) {
      try {
        final resolvedPropertyId = await _findOwnerPropertyIdByName(
          ownerId: ownerId,
          propertyName: ownerPropertyName,
        );
        if (resolvedPropertyId != null && resolvedPropertyId.isNotEmpty) {
          if (tenantIsLinkedToOwnerApp && tenantPropertyName.isNotEmpty) {
            final matches = _normalizePropertyName(tenantPropertyName) ==
                _normalizePropertyName(ownerPropertyName);
            if (!matches) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tenant property name does not match owner property. Update tenant property details to continue.',
                  ),
                ),
              );
              return;
            }
          }

          propertyId = resolvedPropertyId;
        }
      } catch (_) {
        // fall through to error message below
      }
    }

    if (propertyId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Property linkage missing for this tenant.'),
        ),
      );
      return;
    }

    try {
      await service.addPayment(
        tenantId: widget.tenantId,
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
      await _loadInitial();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  /// Update a payment status (paid, partial, unpaid)
  /// Updates Firebase and refreshes local list
  Future<void> _updatePaymentStatus(
    String paymentId,
    String newStatus, {
    int? installmentAmount,
    String? installmentMethod,
    String? installmentNotes,
  }) async {
    try {
      final service = ref.read(tenantPaymentHistoryServiceProvider);
      await service.updatePaymentStatus(
        paymentId: paymentId,
        newStatus: newStatus,
        installmentAmount: installmentAmount,
        installmentMethod: installmentMethod,
        installmentNotes: installmentNotes,
      );

      // Update local state
      if (mounted) {
        final index = _items.indexWhere((item) => item.id == paymentId);
        if (index >= 0) {
          final current = _items[index];
          final amountToAdd = newStatus == 'partial'
              ? (installmentAmount ?? 0)
              : 0;

          final nextPaid = switch (newStatus) {
            'paid' => current.baseAmount,
            'unpaid' => 0,
            _ => (current.paidAmount + amountToAdd).clamp(
              0,
              current.baseAmount,
            ),
          };
          final nextRemaining = (current.baseAmount - nextPaid).clamp(
            0,
            current.baseAmount,
          );
          final normalizedStatus = nextRemaining == 0
              ? (nextPaid > 0 ? 'paid' : 'unpaid')
              : (nextPaid > 0 ? 'partial' : 'unpaid');

          final installments = [...current.installments];
          if (newStatus == 'partial' && amountToAdd > 0) {
            installments.add(
              PaymentInstallment(
                amount: amountToAdd,
                date: DateTime.now(),
                method: installmentMethod ?? current.method,
                notes: installmentNotes,
              ),
            );
          }

          final updatedRecord = TenantPaymentRecord(
            id: current.id,
            tenantId: current.tenantId,
            propertyId: current.propertyId,
            amount: current.baseAmount,
            date: current.date,
            method: current.method,
            status: normalizedStatus,
            createdAt: current.createdAt,
            baseAmount: current.baseAmount,
            paidAmount: nextPaid,
            remainingAmount: nextRemaining,
            transactionId: current.transactionId,
            notes: current.notes,
            installments: newStatus == 'unpaid' ? const [] : installments,
          );
          setState(() {
            _items[index] = updatedRecord;
          });
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackHandler.normal(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Tenant Payment History'),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddPaymentSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Payment'),
        ),
        body: RefreshIndicator(
          onRefresh: _loadInitial,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 120 &&
                  _hasMore &&
                  !_isLoadingMore) {
                _loadMore();
              }
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
              children: [
                _SummaryCard(
                  propertyName: widget.propertyName,
                  tenantName: widget.tenantName,
                  roomNumber: widget.roomNumber,
                  rentAmount: widget.rentAmount,
                  phone: widget.phone,
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const _HistorySkeletonLoader()
                else if (_error != null && _items.isEmpty)
                  _HistoryError(message: _error!, onRetry: _loadInitial)
                else if (_items.isEmpty)
                  const _EmptyHistory()
                else
                  ..._buildGroupedPayments(_items),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                if (_loadMoreError != null && _items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _HistoryError(
                      message: _loadMoreError!,
                      onRetry: _loadMore,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedPayments(List<TenantPaymentRecord> records) {
    final grouped = <String, List<TenantPaymentRecord>>{};

    for (final record in records) {
      final key = _monthKey(record.date);
      grouped.putIfAbsent(key, () => <TenantPaymentRecord>[]).add(record);
    }

    final monthKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final key in monthKeys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            key,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );

      final monthRecords = grouped[key]!
        ..sort((a, b) => b.date.compareTo(a.date));

      for (final record in monthRecords) {
        widgets.add(
          RepaintBoundary(
            child: PaymentHistoryCard(
              payment: record,
              onStatusChanged: _updatePaymentStatus,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 10));
      }
    }

    return widgets;
  }

  String _monthKey(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _showAddPaymentSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return AddPaymentForm(
          onSubmit: _addPayment,
          rentAmount: widget.rentAmount ?? 0,
          existingPayments: _items,
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.propertyName,
    required this.tenantName,
    required this.roomNumber,
    required this.rentAmount,
    required this.phone,
  });

  final String? propertyName;
  final String? tenantName;
  final String? roomNumber;
  final int? rentAmount;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tenantName?.trim().isNotEmpty == true
                ? tenantName!.trim()
                : 'Tenant',
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
              _pill(context, 'Property: ${propertyName ?? 'NA'}'),
              _pill(context, 'Room: ${roomNumber ?? 'NA'}'),
              _pill(context, 'Monthly Rent: Rs ${rentAmount ?? 0}'),
              if ((phone ?? '').trim().isNotEmpty)
                _pill(context, 'Phone: ${phone!}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
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

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 18,
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 18,
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 42),
          SizedBox(height: 8),
          Text(
            'No payment history available for this tenant.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton loader for payment history initial load.
class _HistorySkeletonLoader extends StatefulWidget {
  const _HistorySkeletonLoader();

  @override
  State<_HistorySkeletonLoader> createState() => _HistorySkeletonLoaderState();
}

class _HistorySkeletonLoaderState extends State<_HistorySkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header skeleton
            Opacity(
              opacity: _opacity.value,
              child: Container(
                height: 16,
                width: 120,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // Payment card skeletons
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: _opacity.value,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              height: 14,
                              width: 100,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              height: 22,
                              width: 60,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              height: 10,
                              width: 160,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

