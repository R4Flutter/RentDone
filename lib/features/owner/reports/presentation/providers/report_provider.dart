import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/reports/di/reports_di.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_filter.dart';

@immutable
class ReportsState {
  const ReportsState({
    required this.isLoading,
    required this.isExporting,
    required this.filter,
    required this.selectedPropertyId,
    required this.propertyOptions,
    required this.yearOptions,
    required this.reportData,
    required this.error,
  });

  final bool isLoading;
  final bool isExporting;
  final ReportFilter filter;
  final String? selectedPropertyId;
  final List<ReportPropertyOption> propertyOptions;
  final List<int> yearOptions;
  final ReportData? reportData;
  final String? error;

  factory ReportsState.initial() {
    return ReportsState(
      isLoading: true,
      isExporting: false,
      filter: ReportFilter.thisMonth(),
      selectedPropertyId: null,
      propertyOptions: const <ReportPropertyOption>[],
      yearOptions: const <int>[],
      reportData: null,
      error: null,
    );
  }

  ReportsState copyWith({
    bool? isLoading,
    bool? isExporting,
    ReportFilter? filter,
    Object? selectedPropertyId = _sentinel,
    List<ReportPropertyOption>? propertyOptions,
    List<int>? yearOptions,
    Object? reportData = _sentinel,
    Object? error = _sentinel,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      filter: filter ?? this.filter,
      selectedPropertyId: identical(selectedPropertyId, _sentinel)
          ? this.selectedPropertyId
          : selectedPropertyId as String?,
      propertyOptions: propertyOptions ?? this.propertyOptions,
      yearOptions: yearOptions ?? this.yearOptions,
      reportData: identical(reportData, _sentinel)
          ? this.reportData
          : reportData as ReportData?,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

class ReportsNotifier extends Notifier<ReportsState> {
  bool _initialized = false;

  @override
  ReportsState build() {
    if (!_initialized) {
      _initialized = true;
      Future.microtask(_initialize);
    }
    return ReportsState.initial();
  }

  Future<void> _initialize() async {
    try {
      final years = await ref.read(getReportYearOptionsUseCaseProvider).call();
      final properties = await ref
          .read(getReportPropertyOptionsUseCaseProvider)
          .call();

      state = state.copyWith(
        yearOptions: years,
        propertyOptions: properties,
        error: null,
      );

      await reload();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyErrorMessage(e));
    }
  }

  Future<void> setFilterType(ReportFilterType type) async {
    final now = DateTime.now();
    ReportFilter nextFilter;
    switch (type) {
      case ReportFilterType.thisMonth:
        nextFilter = ReportFilter.thisMonth(now: now);
        break;
      case ReportFilterType.thisYear:
        nextFilter = ReportFilter.thisYear(now: now);
        break;
      case ReportFilterType.custom:
        nextFilter = state.filter.copyWith(type: ReportFilterType.custom);
        break;
    }

    state = state.copyWith(filter: nextFilter);
    await reload();
  }

  Future<void> setCustomDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    state = state.copyWith(
      filter: ReportFilter(
        type: ReportFilterType.custom,
        startDate: normalizedStart,
        endDate: normalizedEnd,
      ),
    );

    await reload();
  }

  Future<void> setProperty(String? propertyId) async {
    final normalized = (propertyId ?? '').trim().isEmpty ? null : propertyId;
    if (state.selectedPropertyId == normalized) {
      return;
    }
    state = state.copyWith(selectedPropertyId: normalized);
    await reload();
  }

  Future<void> setYear(int year) async {
    final currentType = state.filter.type;
    final updated = ReportFilter(
      type: currentType,
      startDate: DateTime(year, 1, 1),
      endDate: DateTime(year, 12, 31, 23, 59, 59),
    );

    state = state.copyWith(filter: updated);
    await reload();
  }

  Future<void> reload() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await ref
          .read(getReportDataUseCaseProvider)
          .call(filter: state.filter, propertyId: state.selectedPropertyId);
      state = state.copyWith(isLoading: false, reportData: data, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyErrorMessage(e));
    }
  }

  Future<String?> export(String format) async {
    final data = state.reportData;
    if (data == null) {
      return null;
    }

    state = state.copyWith(isExporting: true);
    try {
      final url = await ref
          .read(exportReportUseCaseProvider)
          .call(
            format: format,
            data: data,
            filter: state.filter,
            propertyId: state.selectedPropertyId,
          );
      state = state.copyWith(isExporting: false);
      return url;
    } catch (e) {
      state = state.copyWith(isExporting: false);
      return null;
    }
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Bad state: ')) {
      final cleaned = raw.substring('Bad state: '.length).trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
    if (raw.startsWith('Exception: ')) {
      final cleaned = raw.substring('Exception: '.length).trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
    return raw;
  }
}

final reportsProvider = NotifierProvider<ReportsNotifier, ReportsState>(
  ReportsNotifier.new,
);
