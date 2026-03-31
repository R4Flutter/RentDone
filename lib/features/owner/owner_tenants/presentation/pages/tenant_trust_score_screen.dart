import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/dashboard_card.dart';
import 'package:rentdone/features/owner/owner_tenants/data/services/tenant_trust_service.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/models/tenant_trust.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/utils/phone_normalizer.dart';

class TenantTrustScoreScreen extends StatelessWidget {
  const TenantTrustScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TenantTrustFinderScreen();
  }
}

class TenantTrustFinderScreen extends StatefulWidget {
  const TenantTrustFinderScreen({super.key});

  @override
  State<TenantTrustFinderScreen> createState() =>
      _TenantTrustFinderScreenState();
}

class _TenantTrustFinderScreenState extends State<TenantTrustFinderScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TenantTrustService _service = TenantTrustService();

  Future<TenantTrust?>? _lookupFuture;
  String _lastNormalizedPhone = '';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();

    final normalized = normalizePhone(_phoneController.text);
    if (!_isValidIndianPhone(normalized)) {
      _showSnackBar('Please enter a valid 10-digit phone number.');
      return;
    }

    setState(() {
      _lastNormalizedPhone = normalized;
      _lookupFuture = _service.getTrustScore(_phoneController.text);
    });
  }

  bool _isValidIndianPhone(String value) {
    return RegExp(r'^[6-9][0-9]{9}$').hasMatch(value);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);

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
          _BackgroundBlobs(isDark: isDark),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const _HeaderCard(),
              const SizedBox(height: 16),
              _TrustFinderCard(controller: _phoneController, onSearch: _search),
              const SizedBox(height: 16),
              _buildResultArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultArea() {
    if (_lookupFuture == null) {
      return const _InfoCard(
        icon: Icons.verified_user_outlined,
        title: 'Ready to search',
        message: 'Enter a tenant phone number to fetch trust insights.',
      );
    }

    return FutureBuilder<TenantTrust?>(
      future: _lookupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }

        if (snapshot.hasError) {
          final message = _errorMessage(snapshot.error);
          return _InfoCard(
            icon: Icons.warning_amber_rounded,
            title: 'Lookup issue',
            message: message,
            tint: AppTheme.warningAmber,
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const _InfoCard(
            icon: Icons.person_search_rounded,
            title: 'Tenant not found',
            message: 'No trust data found for this tenant.',
          );
        }

        return _ResultCard(trust: data, normalizedPhone: _lastNormalizedPhone);
      },
    );
  }

  String _errorMessage(Object? error) {
    if (error is TenantTrustAuthException) {
      return error.message;
    }
    if (error is TenantTrustPermissionException) {
      return 'Access permission denied.';
    }
    if (error is TenantTrustNetworkException) {
      return 'Please check internet connection.';
    }
    if (error is TenantTrustValidationException) {
      return error.message;
    }
    if (error is TenantTrustDataException) {
      return error.message;
    }
    return 'Unable to fetch trust score right now. Please try again.';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 22,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.26),
              ),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: OwnerDashboardColors.brandPrimary(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tenant Trust Finder',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: OwnerDashboardColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Secure lookup by normalized phone in tenantTrust',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OwnerDashboardColors.textSecondary(context),
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

class _TrustFinderCard extends StatelessWidget {
  const _TrustFinderCard({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find tenant by phone',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: OwnerDashboardColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              LengthLimitingTextInputFormatter(14),
            ],
            onSubmitted: (_) => onSearch(),
            style: TextStyle(color: OwnerDashboardColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: '8668531537 or +91 8668531537',
              hintStyle: TextStyle(
                color: OwnerDashboardColors.textSecondary(context),
              ),
              prefixIcon: Icon(
                Icons.phone_rounded,
                color: OwnerDashboardColors.brandPrimary(context),
              ),
              filled: true,
              fillColor: OwnerDashboardColors.brandPrimary(context).withValues(
                alpha: OwnerDashboardColors.isDark(context) ? 0.10 : 0.05,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: OwnerDashboardColors.border(context),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: OwnerDashboardColors.brandPrimary(context),
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Normalization supports 10-digit, +91, and 91 prefix formats.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OwnerDashboardColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search Trust Score'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OwnerDashboardColors.brandPrimary(context),
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.trust, required this.normalizedPhone});

  final TenantTrust trust;
  final String normalizedPhone;

  @override
  Widget build(BuildContext context) {
    final trustColor = _scoreColor(trust.trustScore);

    return DashboardCard(
      radius: 22,
      inset: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: OwnerDashboardColors.brandPrimary(
                  context,
                ).withValues(alpha: 0.18),
                child: Icon(
                  Icons.person_rounded,
                  color: OwnerDashboardColors.brandPrimary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      normalizedPhone,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OwnerDashboardColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Payment Reliability: ${trust.paymentReliability}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OwnerDashboardColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              _TagPill(label: 'Trust ${trust.trustScore}', color: trustColor),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: trust.trustScore / 100,
              minHeight: 10,
              backgroundColor: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(trustColor),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Total Properties Stayed',
                value: '${trust.propertiesStayed}',
              ),
              _MetricPill(
                label: 'Late Payments',
                value: '${trust.latePayments}',
              ),
              _MetricPill(
                label: 'On-time Payment Rate',
                value: '${trust.onTimeRate}%',
              ),
              _MetricPill(label: 'Complaints', value: '${trust.complaints}'),
              _MetricPill(
                label: 'Total Payments',
                value: '${trust.totalPayments}',
              ),
              _MetricPill(
                label: 'Last Updated',
                value: trust.lastUpdated == null
                    ? 'NA'
                    : DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(trust.lastUpdated!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.successGreen;
    if (score >= 60) return AppTheme.warningAmber;
    return AppTheme.errorRed;
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: OwnerDashboardColors.brandPrimary(
          context,
        ).withValues(alpha: OwnerDashboardColors.isDark(context) ? 0.10 : 0.06),
        border: Border.all(color: OwnerDashboardColors.border(context)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: OwnerDashboardColors.textPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? OwnerDashboardColors.brandPrimary(context);

    return DashboardCard(
      radius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: OwnerDashboardColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OwnerDashboardColors.textSecondary(context),
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      radius: 18,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                OwnerDashboardColors.brandPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Looking up tenant trust profile...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OwnerDashboardColors.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
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
