import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class PropertyOverviewScreen extends StatelessWidget {
  const PropertyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Property Overview")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1200 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summarySection(theme),
                    const SizedBox(height: 32),
                    Expanded(
                      child: _propertyGrid(isDesktop),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // TOP SUMMARY CARDS
  // =========================================================

  Widget _summarySection(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(theme, "Total Properties", "12"),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard(theme, "Occupied", "8"),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard(theme, "Vacant", "4"),
        ),
      ],
    );
  }

  Widget _summaryCard(ThemeData theme, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.displayMedium),
        ],
      ),
    );
  }

  // =========================================================
  // PROPERTY GRID
  // =========================================================

  Widget _propertyGrid(bool isDesktop) {
    return GridView.builder(
      itemCount: 8,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 1,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: isDesktop ? 1.4 : 1.8,
      ),
      itemBuilder: (context, index) {
        final isVacant = index % 3 == 0;

        return _propertyCard(
          context,
          propertyName: "Sunshine Residency - Flat ${index + 1}",
          tenantName: isVacant ? null : "Rahul Sharma",
          phone: isVacant ? null : "9876543210",
        );
      },
    );
  }

  // =========================================================
  // PROPERTY CARD
  // =========================================================

  Widget _propertyCard(
    BuildContext context, {
    required String propertyName,
    String? tenantName,
    String? phone,
  }) {
    final theme = Theme.of(context);
    final isVacant = tenantName == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(propertyName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),

          if (isVacant) ...[
            Text(
              "Status: Vacant",
              style: theme.textTheme.bodyLarge,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Add Tenant"),
            ),
          ] else ...[
            Text("Tenant: $tenantName",
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text("Phone: $phone",
                style: theme.textTheme.bodyMedium),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text("View"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("Manage"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}