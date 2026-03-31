import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';
import 'package:rentdone/features/payment/presentation/providers/payment_di.dart';

class TransactionHistoryState {
  final List<TransactionRecord> transactions;
  final bool hasMore;
  final bool isLoadingMore;
  final int? selectedYear;
  final String selectedStatus;

  const TransactionHistoryState({
    required this.transactions,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedYear,
    required this.selectedStatus,
  });

  TransactionHistoryState copyWith({
    List<TransactionRecord>? transactions,
    bool? hasMore,
    bool? isLoadingMore,
    int? selectedYear,
    String? selectedStatus,
  }) {
    return TransactionHistoryState(
      transactions: transactions ?? this.transactions,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedStatus: selectedStatus ?? this.selectedStatus,
    );
  }

  factory TransactionHistoryState.initial() {
    return const TransactionHistoryState(
      transactions: [],
      hasMore: true,
      isLoadingMore: false,
      selectedYear: null,
      selectedStatus: 'all',
    );
  }
}

class TransactionHistoryNotifier
    extends AsyncNotifier<TransactionHistoryState> {
  static const _pageSize = 20;

  TransactionActor actor = TransactionActor.tenant;
  String? actorId;
  DateTime? _cursorCreatedAt;
  String? _cursorDocId;
  bool _hasLoadedInitial = false;

  @override
  Future<TransactionHistoryState> build() async {
    return TransactionHistoryState.initial();
  }

  Future<void> loadInitial({
    required TransactionActor actor,
    String? actorId,
    bool force = false,
  }) async {
    final resolvedActorId = actorId ?? FirebaseAuth.instance.currentUser?.uid;

    if (!force && state.isLoading) {
      return;
    }

    if (!force &&
        _hasLoadedInitial &&
        this.actor == actor &&
        this.actorId == resolvedActorId) {
      return;
    }

    this.actor = actor;
    this.actorId = resolvedActorId;

    final current = state.value ?? TransactionHistoryState.initial();
    final selectedYear = current.selectedYear;
    final selectedStatus = current.selectedStatus;

    if (this.actorId == null) {
      state = AsyncValue.error(const UnauthorizedFailure(), StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(getTransactionHistoryUseCaseProvider)
          .call(
            actor: actor,
            actorId: this.actorId!,
            limit: _pageSize,
            year: selectedYear,
            status: selectedStatus,
          );

      _cursorCreatedAt = page.nextCreatedAt;
      _cursorDocId = page.nextDocId;
      _hasLoadedInitial = true;

      return TransactionHistoryState.initial().copyWith(
        transactions: page.items,
        hasMore: page.hasMore,
        selectedYear: selectedYear,
        selectedStatus: selectedStatus,
      );
    });
  }

  Future<void> refresh() async {
    await loadInitial(actor: actor, actorId: actorId, force: true);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    final result = await AsyncValue.guard(() async {
      final page = await ref
          .read(getTransactionHistoryUseCaseProvider)
          .call(
            actor: actor,
            actorId: actorId!,
            limit: _pageSize,
            year: current.selectedYear,
            status: current.selectedStatus,
            startAfterCreatedAt: _cursorCreatedAt,
            startAfterDocId: _cursorDocId,
          );

      _cursorCreatedAt = page.nextCreatedAt;
      _cursorDocId = page.nextDocId;

      return current.copyWith(
        transactions: [...current.transactions, ...page.items],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    });

    if (result.hasError) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      return;
    }

    state = AsyncValue.data(result.value!);
  }

  Future<void> setFilters({int? year, String? status}) async {
    final current = state.value ?? TransactionHistoryState.initial();
    final updated = current.copyWith(
      selectedYear: year,
      selectedStatus: status ?? current.selectedStatus,
    );

    state = AsyncValue.data(updated);
    await loadInitial(actor: actor, actorId: actorId, force: true);
  }
}

final transactionHistoryProvider =
    AsyncNotifierProvider<TransactionHistoryNotifier, TransactionHistoryState>(
      TransactionHistoryNotifier.new,
    );
