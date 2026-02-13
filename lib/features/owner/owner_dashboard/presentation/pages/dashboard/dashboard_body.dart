import 'package:flutter/material.dart';

import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard_main/property_tile.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard_main/section_wrapper.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard_main/summary.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding(context),
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================================================
          // HEADER
          // =========================================================

          Text(
            'Dashboard',
            style: text.displayMedium,
            
          ),

          const SizedBox(height: 6),

          Text(
            'Your rental portfolio overview',
            style: text.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha:0.7),
            ),
          ),

          const SizedBox(height: 32),

          // =========================================================
          // TOP SUMMARY GRID
          // =========================================================

          LayoutBuilder(
            builder: (context, constraints) {
              final config = _summaryGridConfig(constraints.maxWidth);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _summaryCards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: config.columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: config.aspectRatio,
                ),
                itemBuilder: (_, index) => _summaryCards[index],
              );
            },
          ),

          const SizedBox(height: 32),

          // =========================================================
          // PAYMENT MODE SUMMARY
          // =========================================================

          Section(
            title: 'Payment Mode Summary',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 700 ? 2 : 4;

                return GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio:
                        constraints.maxWidth < 700 ? 1.3 : 1.8,
                  ),
                  children: const [
                    SummaryCard(
                      imagePath: 'assets/images/cash.png',
                      title: 'Cash',
                      value: '₹45,000',
                      subtitle: 'Collected',
                    ),
                    SummaryCard(
                      imagePath: 'assets/images/upi.png',
                      title: 'Online',
                      value: '₹25,000',
                      subtitle: 'Collected',
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // =========================================================
          // PROPERTIES OVERVIEW
          // =========================================================

          Section(
            title: 'Properties Overview',
            child: Column(
              children: const [
                PropertyTile(
                  name: 'Sunshine Apartments 2BHK',
                  tenant: 'Priya Sharma',
                  rent: '₹25,000/mo',
                  status: PropertyStatus.paid,
                ),
                SizedBox(height: 16),
                PropertyTile(
                  name: 'Green Valley Villa',
                  tenant: 'Amit Patel',
                  rent: '₹35,000/mo',
                  status: PropertyStatus.paid,
                ),
                SizedBox(height: 16),
                PropertyTile(
                  name: 'Commercial Shop - Plaza',
                  tenant: 'Vacant',
                  rent: '₹45,000/mo',
                  status: PropertyStatus.vacant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // RESPONSIVE HELPERS
  // =============================================================

  static double _horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 48; // desktop
    if (width >= 800) return 32;  // tablet
    return 24;                    // mobile
  }

  static _GridConfig _summaryGridConfig(double width) {
    if (width >= 1200) {
      return const _GridConfig(columns: 4, aspectRatio: 1.8);
    } else if (width >= 800) {
      return const _GridConfig(columns: 3, aspectRatio: 1.6);
    }
    return const _GridConfig(columns: 2, aspectRatio: 1.25);
  }
}

// ===============================================================
// DATA (NO COLORS HERE — PURE UI CONFIG)
// ===============================================================

const List<Widget> _summaryCards = [
  SummaryCard(
    imagePath: 'assets/images/tenant_final.png',
    title: 'Tenants',
    value: '4',
    subtitle: 'Active tenants',
  ),
  SummaryCard(
    imagePath: 'assets/images/property.png',
    title: 'Properties',
    value: '300',
    subtitle: '1 Vacant',
  ),
  SummaryCard(
    imagePath: 'assets/images/collected.png',
    title: 'Collected',
    value: '₹70,00000',
    subtitle: '2 payments',
  ),
  SummaryCard(
    imagePath: 'assets/images/pending.png',
    title: 'Pending',
    value: '₹25,000000',
    subtitle: '1 payment',
  ),
];

class _GridConfig {
  final int columns;
  final double aspectRatio;

  const _GridConfig({
    required this.columns,
    required this.aspectRatio,
  });
}