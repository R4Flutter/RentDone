import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String selectedMonth = "February 2026";
  String selectedProperty = "All Properties";
  String selectedStatus = "All";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rent Payments"),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text("Export Report"),
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
                constraints:
                    BoxConstraints(maxWidth: isDesktop ? 1400 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filterBar(theme),
                    const SizedBox(height: 32),
                    _kpiSection(theme),
                    const SizedBox(height: 40),
                    isDesktop
                        ? _desktopTable(theme)
                        : _mobileList(theme),
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

  Widget _filterBar(ThemeData theme) {
    return Wrap(
      spacing: 20,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        DropdownButton<String>(
          value: selectedMonth,
          onChanged: (v) => setState(() => selectedMonth = v!),
          items: ["January 2026", "February 2026", "March 2026"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
        DropdownButton<String>(
          value: selectedProperty,
          onChanged: (v) => setState(() => selectedProperty = v!),
          items: ["All Properties", "Sunshine Residency"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
        DropdownButton<String>(
          value: selectedStatus,
          onChanged: (v) => setState(() => selectedStatus = v!),
          items: ["All", "Paid", "Pending", "Overdue"]
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search Tenant...",
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // KPI SECTION
  // ==========================================================

  Widget _kpiSection(ThemeData theme) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _kpiCard(theme, "Expected", "₹ 2,50,000"),
        _kpiCard(theme, "Collected", "₹ 2,10,000"),
        _kpiCard(theme, "Pending", "₹ 25,000"),
        _kpiCard(theme, "Overdue", "₹ 15,000"),
        _kpiCard(theme, "Collection Rate", "84%"),
      ],
    );
  }

  Widget _kpiCard(ThemeData theme, String title, String value) {
    return Container(
      width: 260,
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
        ],
      ),
    );
  }

  // ==========================================================
  // DESKTOP TABLE VIEW
  // ==========================================================

  Widget _desktopTable(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Tenant")),
          DataColumn(label: Text("Property")),
          DataColumn(label: Text("Amount")),
          DataColumn(label: Text("Due Date")),
          DataColumn(label: Text("Status")),
          DataColumn(label: Text("Action")),
        ],
        rows: [
          _row("Rahul Sharma", "Sunshine Residency", "₹20,000",
              "10 Feb 2026", "Paid"),
          _row("Amit Verma", "Palm Heights", "₹18,000",
              "10 Feb 2026", "Pending"),
          _row("Neha Singh", "Sunshine Residency", "₹22,000",
              "5 Feb 2026", "Overdue"),
        ],
      ),
    );
  }

  DataRow _row(String tenant, String property, String amount,
      String dueDate, String status) {
    return DataRow(cells: [
      DataCell(Text(tenant)),
      DataCell(Text(property)),
      DataCell(Text(amount)),
      DataCell(Text(dueDate)),
      DataCell(Text(status)),
      DataCell(ElevatedButton(
        onPressed: () {},
        child: const Text("View"),
      )),
    ]);
  }

  // ==========================================================
  // MOBILE LIST VIEW
  // ==========================================================

  Widget _mobileList(ThemeData theme) {
    return Column(
      children: [
        _paymentCard(theme, "Rahul Sharma", "₹20,000", "Paid"),
        const SizedBox(height: 20),
        _paymentCard(theme, "Amit Verma", "₹18,000", "Pending"),
        const SizedBox(height: 20),
        _paymentCard(theme, "Neha Singh", "₹22,000", "Overdue"),
      ],
    );
  }

  Widget _paymentCard(
      ThemeData theme, String tenant, String amount, String status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tenant, style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text("Amount: $amount"),
          const SizedBox(height: 6),
          Text("Status: $status"),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: const Text("View Payment"),
          )
        ],
      ),
    );
  }
}