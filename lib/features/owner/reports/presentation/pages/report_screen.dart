import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool isMonthly = true;
  String selectedYear = "2026";
  String selectedProperty = "All Properties";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Financial Reports"),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text("Export PDF"),
          ),
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
                    maxWidth: isDesktop ? 1400 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filterBar(theme, isDesktop),
                    const SizedBox(height: 32),
                    _kpiSection(theme, isDesktop),
                    const SizedBox(height: 40),
                    _analyticsSection(theme, isDesktop),
                    const SizedBox(height: 40),
                    _propertyPerformance(theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // FILTER BAR
  // ==========================================================

  Widget _filterBar(ThemeData theme, bool isDesktop) {
    return Wrap(
      spacing: 20,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ToggleButtons(
          borderRadius: BorderRadius.circular(12),
          isSelected: [isMonthly, !isMonthly],
          onPressed: (i) => setState(() => isMonthly = i == 0),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("Monthly"),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("Yearly"),
            ),
          ],
        ),
        DropdownButton<String>(
          value: selectedYear,
          onChanged: (v) => setState(() => selectedYear = v!),
          items: ["2024", "2025", "2026"]
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text("Year $e")))
              .toList(),
        ),
        DropdownButton<String>(
          value: selectedProperty,
          onChanged: (v) => setState(() => selectedProperty = v!),
          items: ["All Properties", "Sunshine Residency"]
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
      ],
    );
  }

  // ==========================================================
  // KPI SECTION
  // ==========================================================

  Widget _kpiSection(ThemeData theme, bool isDesktop) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _kpiCard(theme, "Total Revenue", "₹ 2,40,000", "+12%"),
        _kpiCard(theme, "Expenses", "₹ 60,000", "-3%"),
        _kpiCard(theme, "Net Profit", "₹ 1,80,000", "+18%"),
        _kpiCard(theme, "Occupancy Rate", "82%", "+5%"),
      ],
    );
  }

  Widget _kpiCard(
      ThemeData theme, String title, String value, String growth) {
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
          Text(
            "Growth: $growth",
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ANALYTICS SECTION
  // ==========================================================

  Widget _analyticsSection(ThemeData theme, bool isDesktop) {
    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: _chartCard(theme, "Revenue vs Expense")),
          const SizedBox(width: 24),
          Expanded(child: _chartCard(theme, "Occupancy Trend")),
        ],
      );
    } else {
      return Column(
        children: [
          _chartCard(theme, "Revenue vs Expense"),
          const SizedBox(height: 24),
          _chartCard(theme, "Occupancy Trend"),
        ],
      );
    }
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

  // ==========================================================
  // PROPERTY PERFORMANCE TABLE
  // ==========================================================

  Widget _propertyPerformance(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Property Performance",
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          DataTable(
            columns: const [
              DataColumn(label: Text("Property")),
              DataColumn(label: Text("Revenue")),
              DataColumn(label: Text("Expenses")),
              DataColumn(label: Text("Occupancy")),
            ],
            rows: const [
              DataRow(cells: [
                DataCell(Text("Sunshine Residency")),
                DataCell(Text("₹1,20,000")),
                DataCell(Text("₹30,000")),
                DataCell(Text("90%")),
              ]),
              DataRow(cells: [
                DataCell(Text("Palm Heights")),
                DataCell(Text("₹1,00,000")),
                DataCell(Text("₹25,000")),
                DataCell(Text("80%")),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}