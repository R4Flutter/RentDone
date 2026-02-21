import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/reports/di/reports_di.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';

@immutable
class ReportsState {
  final bool isLoading;
  final bool isMonthly;
  final String selectedYear;
  final String selectedProperty;
  final List<String> yearOptions;
  final List<String> propertyOptions;
  final ReportData? reportData;
  final String? error;

  const ReportsState({
    required this.isLoading,
    required this.isMonthly,
    required this.selectedYear,
    required this.selectedProperty,
    required this.yearOptions,
    required this.propertyOptions,
    required this.reportData,
    required this.error,
  });

  factory ReportsState.initial() {
    return const ReportsState(
      isLoading: true,
      isMonthly: true,
      selectedYear: '2026',
      selectedProperty: 'All Properties',
      yearOptions: <String>[],
      propertyOptions: <String>[],
      reportData: null,
      error: null,
    );
  }

  ReportsState copyWith({
    bool? isLoading,
    bool? isMonthly,
    String? selectedYear,
    String? selectedProperty,
    List<String>? yearOptions,
    List<String>? propertyOptions,
    ReportData? reportData,
    Object? error = _sentinel,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      isMonthly: isMonthly ?? this.isMonthly,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedProperty: selectedProperty ?? this.selectedProperty,
      yearOptions: yearOptions ?? this.yearOptions,
      propertyOptions: propertyOptions ?? this.propertyOptions,
      reportData: reportData ?? this.reportData,
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

      final selectedYear = years.contains(state.selectedYear)
          ? state.selectedYear
          : (years.isNotEmpty ? years.first : state.selectedYear);
      final selectedProperty = properties.contains(state.selectedProperty)
          ? state.selectedProperty
          : (properties.isNotEmpty ? properties.first : state.selectedProperty);

      state = state.copyWith(
        yearOptions: years,
        propertyOptions: properties,
        selectedYear: selectedYear,
        selectedProperty: selectedProperty,
        error: null,
      );

      await _reload();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> setPeriod(bool isMonthly) async {
    if (state.isMonthly == isMonthly) {
      return;
    }
    state = state.copyWith(isMonthly: isMonthly);
    await _reload();
  }

  Future<void> setYear(String year) async {
    if (state.selectedYear == year) {
      return;
    }
    state = state.copyWith(selectedYear: year);
    await _reload();
  }

  Future<void> setProperty(String property) async {
    if (state.selectedProperty == property) {
      return;
    }
    state = state.copyWith(selectedProperty: property);
    await _reload();
  }

  Future<void> retry() async {
    await _reload();
  }

  Future<void> _reload() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await ref
          .read(getReportDataUseCaseProvider)
          .call(
            isMonthly: state.isMonthly,
            year: state.selectedYear,
            property: state.selectedProperty,
          );
      state = state.copyWith(isLoading: false, reportData: data, error: null);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}

final reportsProvider = NotifierProvider<ReportsNotifier, ReportsState>(
  ReportsNotifier.new,
);
