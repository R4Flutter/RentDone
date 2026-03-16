import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_data.dart';
import 'package:rentdone/features/owner/reports/domain/entities/report_filter.dart';
import 'package:rentdone/features/owner/reports/presentation/providers/report_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsProvider);
    final notifier = ref.read(reportsProvider.notifier);
    final reportData = state.reportData;

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                  context,
                ),
              ),
            ),
          ),
          _BackgroundBlobs(isDark: OwnerDashboardColors.isDark(context)),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: notifier.reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  _Header(
                    filter: state.filter,
                    isExporting: state.isExporting,
                    onExportPdf: () => _export(context, notifier, 'pdf'),
                    onExportExcel: () => _export(context, notifier, 'xlsx'),
                  ),
                  const SizedBox(height: 14),
                  _FiltersCard(
                    state: state,
                    onFilterTypeChanged: notifier.setFilterType,
                    onPropertyChanged: notifier.setProperty,
                    onYearChanged: notifier.setYear,
                    onCustomDateRangeChanged: (start, end) => notifier
                        .setCustomDateRange(startDate: start, endDate: end),
                  ),
                  const SizedBox(height: 16),
                  if (state.isLoading && reportData == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.error != null && reportData == null)
                    _ErrorCard(message: state.error!, onRetry: notifier.reload)
                  else if (reportData != null) ...[
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InlineWarning(message: state.error!),
                      ),
                    _SummaryGrid(data: reportData),
                    const SizedBox(height: 16),
                    _ChartsGrid(data: reportData),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Property Income Breakdown'),
                    const SizedBox(height: 10),
                    _PropertyIncomeTable(data: reportData),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Tenant Payment Status'),
                    const SizedBox(height: 10),
                    _TenantStatusTable(data: reportData),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Overdue Tenants'),
                    const SizedBox(height: 10),
                    _OverdueList(data: reportData),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Top Paying Tenants'),
                    const SizedBox(height: 10),
                    _TopTenants(data: reportData),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    ReportsNotifier notifier,
    String format,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await notifier.export(format);
    if (!context.mounted) {
      return;
    }

    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to export report right now.')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Export created. Download URL: $url'),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.isExporting,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  final ReportFilter filter;
  final bool isExporting;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;

  @override
  Widget build(BuildContext context) {
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return DashboardCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: OwnerDashboardColors.brandPrimary(
                    context,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: OwnerDashboardColors.brandPrimary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports Dashboard',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(filter.startDate)} to ${_formatDate(filter.endDate)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: isExporting ? null : onExportPdf,
                icon: isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Export PDF'),
              ),
              OutlinedButton.icon(
                onPressed: isExporting ? null : onExportExcel,
                icon: const Icon(Icons.grid_on_rounded),
                label: const Text('Export Excel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.state,
    required this.onFilterTypeChanged,
    required this.onPropertyChanged,
    required this.onYearChanged,
    required this.onCustomDateRangeChanged,
  });

  final ReportsState state;
  final ValueChanged<ReportFilterType> onFilterTypeChanged;
  final ValueChanged<String?> onPropertyChanged;
  final ValueChanged<int> onYearChanged;
  final Future<void> Function(DateTime, DateTime) onCustomDateRangeChanged;

  @override
  Widget build(BuildContext context) {
    final selectedYear = state.filter.startDate.year;

    return DashboardCard(
      radius: 20,
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<ReportFilterType>(
            segments: const [
              ButtonSegment<ReportFilterType>(
                value: ReportFilterType.thisMonth,
                label: Text('This Month'),
              ),
              ButtonSegment<ReportFilterType>(
                value: ReportFilterType.thisYear,
                label: Text('This Year'),
              ),
              ButtonSegment<ReportFilterType>(
                value: ReportFilterType.custom,
                label: Text('Custom'),
              ),
            ],
            selected: <ReportFilterType>{state.filter.type},
            onSelectionChanged: (selection) {
              onFilterTypeChanged(selection.first);
            },
          ),
          DropdownButton<String?>(
            value: state.selectedPropertyId,
            hint: const Text('All Properties'),
            onChanged: onPropertyChanged,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Properties'),
              ),
              ...state.propertyOptions.map(
                (entry) => DropdownMenuItem<String?>(
                  value: entry.id,
                  child: Text(entry.name),
                ),
              ),
            ],
          ),
          if (state.yearOptions.isNotEmpty)
            DropdownButton<int>(
              value: state.yearOptions.contains(selectedYear)
                  ? selectedYear
                  : state.yearOptions.first,
              onChanged: (value) {
                if (value != null) {
                  onYearChanged(value);
                }
              },
              items: state.yearOptions
                  .map(
                    (year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text('Year $year'),
                    ),
                  )
                  .toList(),
            ),
          if (state.filter.type == ReportFilterType.custom)
            OutlinedButton.icon(
              onPressed: () => _pickCustomRange(context),
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                '${_formatDate(state.filter.startDate)} - ${_formatDate(state.filter.endDate)}',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: state.filter.startDate,
        end: state.filter.endDate,
      ),
    );

    if (range == null) {
      return;
    }

    await onCustomDateRangeChanged(range.start, range.end);
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final vacancyRate = data.vacancyReport.totalRooms == 0
        ? 0.0
        : (data.vacancyReport.vacantRooms / data.vacancyReport.totalRooms) *
              100;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 980;
        final medium = constraints.maxWidth > 620;
        final itemWidth = wide
            ? (constraints.maxWidth - 24) / 4
            : medium
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _KpiCard(
              width: itemWidth,
              title: 'Expected',
              value: _money(data.monthlySummary.expected),
              subtitle: 'Rent due in selected period',
              color: AppTheme.infoBlue,
              icon: Icons.trending_up_rounded,
            ),
            _KpiCard(
              width: itemWidth,
              title: 'Collected',
              value: _money(data.monthlySummary.collected),
              subtitle:
                  '${data.monthlySummary.collectionRate.toStringAsFixed(1)}% collection rate',
              color: AppTheme.successGreen,
              icon: Icons.payments_rounded,
            ),
            _KpiCard(
              width: itemWidth,
              title: 'Pending',
              value: _money(data.monthlySummary.pending),
              subtitle: '${data.overdueTenants.length} overdue tenants',
              color: AppTheme.warningAmber,
              icon: Icons.hourglass_bottom_rounded,
            ),
            _KpiCard(
              width: itemWidth,
              title: 'Vacancy Rate',
              value: '${vacancyRate.toStringAsFixed(1)}%',
              subtitle:
                  '${data.vacancyReport.vacantRooms}/${data.vacancyReport.totalRooms} rooms vacant',
              color: AppTheme.errorRed,
              icon: Icons.bed_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DashboardCard(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OwnerDashboardColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: OwnerDashboardColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OwnerDashboardColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartsGrid extends StatelessWidget {
  const _ChartsGrid({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth > 860;
        if (twoColumns) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TrendChart(data: data)),
              const SizedBox(width: 12),
              Expanded(child: _MethodPieChart(data: data)),
            ],
          );
        }

        return Column(
          children: [
            _TrendChart(data: data),
            const SizedBox(height: 12),
            _MethodPieChart(data: data),
          ],
        );
      },
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final points = data.monthlyTrend;
    final maxY = max<int>(
      1,
      points.fold<int>(0, (prev, e) => e.amount > prev ? e.amount : prev),
    );

    return DashboardCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: '6-Month Collection Trend'),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: (maxY * 1.2).ceilToDouble(),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: max(1, (maxY / 4).ceil()).toDouble(),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: OwnerDashboardColors.border(context),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: max(1, (maxY / 4).ceil()).toDouble(),
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _compactMoney(value.toInt()),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            points[idx].label,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].amount.toDouble()),
                    ],
                    color: OwnerDashboardColors.brandPrimary(context),
                    barWidth: 3,
                    isCurved: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, spot, barData, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: OwnerDashboardColors.brandPrimary(context),
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          OwnerDashboardColors.brandPrimary(
                            context,
                          ).withValues(alpha: 0.24),
                          OwnerDashboardColors.brandPrimary(
                            context,
                          ).withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodPieChart extends StatelessWidget {
  const _MethodPieChart({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final slices = data.paymentMethodBreakdown
        .where((e) => e.amount > 0)
        .toList();
    final total = slices.fold<int>(0, (p, e) => p + e.amount);

    final colors = <Color>[
      AppTheme.infoBlue,
      AppTheme.successGreen,
      AppTheme.warningAmber,
      OwnerDashboardColors.brandPrimary(context),
    ];

    return DashboardCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Payment Methods'),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: slices.isEmpty
                ? const Center(child: Text('No payment method data available'))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 46,
                      sections: [
                        for (int i = 0; i < slices.length; i++)
                          PieChartSectionData(
                            value: slices[i].amount.toDouble(),
                            color: colors[i % colors.length],
                            radius: 54,
                            title: total == 0
                                ? '0%'
                                : '${((slices[i].amount / total) * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < slices.length; i++)
                _LegendChip(
                  color: colors[i % colors.length],
                  label: '${slices[i].method}: ${_money(slices[i].amount)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _PropertyIncomeTable extends StatelessWidget {
  const _PropertyIncomeTable({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    if (data.propertyIncome.isEmpty) {
      return const _EmptyCard(message: 'No property income data available.');
    }

    return DashboardCard(
      radius: 18,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          columns: const [
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Expected')),
            DataColumn(label: Text('Collected')),
            DataColumn(label: Text('Pending')),
          ],
          rows: data.propertyIncome
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(Text(entry.propertyName)),
                    DataCell(Text(_money(entry.expected))),
                    DataCell(Text(_money(entry.collected))),
                    DataCell(Text(_money(entry.pending))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TenantStatusTable extends StatelessWidget {
  const _TenantStatusTable({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    if (data.tenantStatuses.isEmpty) {
      return const _EmptyCard(
        message: 'No tenant payment status records found.',
      );
    }

    return DashboardCard(
      radius: 18,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          columns: const [
            DataColumn(label: Text('Tenant')),
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Room')),
            DataColumn(label: Text('Rent')),
            DataColumn(label: Text('Status')),
          ],
          rows: data.tenantStatuses
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(Text(entry.tenantName)),
                    DataCell(Text(entry.propertyName)),
                    DataCell(Text(entry.roomNumber)),
                    DataCell(Text(_money(entry.monthlyRent))),
                    DataCell(_StatusPill(status: entry.status)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _OverdueList extends StatelessWidget {
  const _OverdueList({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    if (data.overdueTenants.isEmpty) {
      return const _EmptyCard(message: 'No overdue tenants in selected range.');
    }

    return Column(
      children: data.overdueTenants
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DashboardCard(
                radius: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.tenantName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Room ${entry.roomNumber} • ${entry.daysLate} days late',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: OwnerDashboardColors.textSecondary(
                                    context,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(entry.pendingAmount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TopTenants extends StatelessWidget {
  const _TopTenants({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    if (data.topPayingTenants.isEmpty) {
      return const _EmptyCard(
        message: 'No paid transactions for top tenant ranking.',
      );
    }

    return DashboardCard(
      radius: 18,
      child: Column(
        children: [
          for (int i = 0; i < data.topPayingTenants.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == data.topPayingTenants.length - 1 ? 0 : 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: OwnerDashboardColors.brandPrimary(
                        context,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${i + 1}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: OwnerDashboardColors.brandPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.topPayingTenants[i].tenantName),
                        Text(
                          data.topPayingTenants[i].propertyName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: OwnerDashboardColors.textSecondary(
                                  context,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(data.topPayingTenants[i].totalPaid),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'paid' => AppTheme.successGreen,
      'partial' => AppTheme.warningAmber,
      _ => AppTheme.errorRed,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized[0].toUpperCase() + normalized.substring(1),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: OwnerDashboardColors.textPrimary(context),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 16,
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: OwnerDashboardColors.textSecondary(context),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 14,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load reports',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -56,
            child: _Blob(size: 270, opacity: isDark ? 0.16 : 0.11),
          ),
          Positioned(
            bottom: -90,
            right: -60,
            child: _Blob(size: 250, opacity: isDark ? 0.14 : 0.09),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            OwnerDashboardColors.brandPrimary(
              context,
            ).withValues(alpha: opacity),
            AppColors.transparent,
          ],
        ),
      ),
    );
  }
}

String _money(int value) {
  return NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ').format(value);
}

String _compactMoney(int value) {
  if (value >= 10000000) {
    return '${(value / 10000000).toStringAsFixed(1)}Cr';
  }
  if (value >= 100000) {
    return '${(value / 100000).toStringAsFixed(1)}L';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}K';
  }
  return value.toString();
}

String _formatDate(DateTime date) {
  return DateFormat('dd MMM yyyy').format(date);
}
