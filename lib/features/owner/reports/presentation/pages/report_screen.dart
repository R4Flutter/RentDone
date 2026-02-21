import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/reports/domain/entities/property_performance.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/presentation/providers/report_provider.dart';

const ReportData _fallbackReportData = ReportData(
  totalRevenue: 'Rs 2,40,000',
  totalRevenueGrowth: '+12%',
  expenses: 'Rs 60,000',
  expensesGrowth: '-3%',
  netProfit: 'Rs 1,80,000',
  netProfitGrowth: '+18%',
  occupancyRate: '82%',
  occupancyGrowth: '+5%',
  propertyPerformance: [
    PropertyPerformance(
      property: 'Sunshine Residency',
      revenue: 'Rs 1,20,000',
      expenses: 'Rs 30,000',
      occupancy: '90%',
    ),
    PropertyPerformance(
      property: 'Palm Heights',
      revenue: 'Rs 1,00,000',
      expenses: 'Rs 25,000',
      occupancy: '80%',
    ),
  ],
);

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(reportsProvider);
    final notifier = ref.read(reportsProvider.notifier);

    if (state.isLoading && state.reportData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.error != null && state.reportData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Financial Reports')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: ${state.error}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: notifier.retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final yearOptions = state.yearOptions.isNotEmpty
        ? state.yearOptions
        : const ['2024', '2025', '2026'];
    final propertyOptions = state.propertyOptions.isNotEmpty
        ? state.propertyOptions
        : const ['All Properties', 'Sunshine Residency', 'Palm Heights'];
    final selectedYear = yearOptions.contains(state.selectedYear)
        ? state.selectedYear
        : yearOptions.first;
    final selectedProperty = propertyOptions.contains(state.selectedProperty)
        ? state.selectedProperty
        : propertyOptions.first;
    final reportData = state.reportData ?? _fallbackReportData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Export PDF')),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1000;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1400 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filterBar(
                      theme,
                      isMonthly: state.isMonthly,
                      yearOptions: yearOptions,
                      selectedYear: selectedYear,
                      propertyOptions: propertyOptions,
                      selectedProperty: selectedProperty,
                      onSelectMonthly: () => notifier.setPeriod(true),
                      onSelectYearly: () => notifier.setPeriod(false),
                      onSelectYear: (value) => notifier.setYear(value),
                      onSelectProperty: (value) => notifier.setProperty(value),
                    ),
                    const SizedBox(height: 32),
                    _kpiSection(theme, reportData),
                    const SizedBox(height: 40),
                    _analyticsSection(theme, isDesktop),
                    const SizedBox(height: 40),
                    _propertyPerformance(theme, reportData),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterBar(
    ThemeData theme, {
    required bool isMonthly,
    required List<String> yearOptions,
    required String selectedYear,
    required List<String> propertyOptions,
    required String selectedProperty,
    required VoidCallback onSelectMonthly,
    required VoidCallback onSelectYearly,
    required ValueChanged<String> onSelectYear,
    required ValueChanged<String> onSelectProperty,
  }) {
    return Wrap(
      spacing: 20,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ToggleButtons(
          borderRadius: BorderRadius.circular(12),
          isSelected: [isMonthly, !isMonthly],
          onPressed: (index) {
            if (index == 0) {
              onSelectMonthly();
            } else {
              onSelectYearly();
            }
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Monthly'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Yearly'),
            ),
          ],
        ),
        DropdownButton<String>(
          value: selectedYear,
          onChanged: (value) {
            if (value != null) {
              onSelectYear(value);
            }
          },
          items: yearOptions
              .map(
                (entry) =>
                    DropdownMenuItem(value: entry, child: Text('Year $entry')),
              )
              .toList(),
        ),
        DropdownButton<String>(
          value: selectedProperty,
          onChanged: (value) {
            if (value != null) {
              onSelectProperty(value);
            }
          },
          items: propertyOptions
              .map(
                (entry) => DropdownMenuItem(value: entry, child: Text(entry)),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _kpiSection(ThemeData theme, ReportData reportData) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _kpiCard(
          theme,
          'Total Revenue',
          reportData.totalRevenue,
          reportData.totalRevenueGrowth,
        ),
        _kpiCard(
          theme,
          'Expenses',
          reportData.expenses,
          reportData.expensesGrowth,
        ),
        _kpiCard(
          theme,
          'Net Profit',
          reportData.netProfit,
          reportData.netProfitGrowth,
        ),
        _kpiCard(
          theme,
          'Occupancy Rate',
          reportData.occupancyRate,
          reportData.occupancyGrowth,
        ),
      ],
    );
  }

  Widget _kpiCard(ThemeData theme, String title, String value, String growth) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.displayMedium),
          const SizedBox(height: 6),
          Text('Growth: $growth', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _analyticsSection(ThemeData theme, bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: _chartCard(theme, 'Revenue vs Expense')),
          const SizedBox(width: 24),
          Expanded(child: _chartCard(theme, 'Occupancy Trend')),
        ],
      );
    }

    return Column(
      children: [
        _chartCard(theme, 'Revenue vs Expense'),
        const SizedBox(height: 24),
        _chartCard(theme, 'Occupancy Trend'),
      ],
    );
  }

  Widget _chartCard(ThemeData theme, String title) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(title, style: theme.textTheme.titleLarge),
      ),
    );
  }

  Widget _propertyPerformance(ThemeData theme, ReportData reportData) {
    final rows = reportData.propertyPerformance;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Property Performance', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          DataTable(
            columns: const [
              DataColumn(label: Text('Property')),
              DataColumn(label: Text('Revenue')),
              DataColumn(label: Text('Expenses')),
              DataColumn(label: Text('Occupancy')),
            ],
            rows: rows
                .map(
                  (entry) => DataRow(
                    cells: [
                      DataCell(Text(entry.property)),
                      DataCell(Text(entry.revenue)),
                      DataCell(Text(entry.expenses)),
                      DataCell(Text(entry.occupancy)),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
