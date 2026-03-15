import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_tenants/di/owner_tenants_di.dart';

class TenantTrustScoreScreen extends ConsumerStatefulWidget {
  const TenantTrustScoreScreen({super.key});

  @override
  ConsumerState<TenantTrustScoreScreen> createState() =>
      _TenantTrustScoreScreenState();
}

class _TenantTrustScoreScreenState
    extends ConsumerState<TenantTrustScoreScreen> {
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  _TrustLookupResult? _result;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _phoneController.text.trim();
    final normalized = _normalizeIndianPhone(raw);

    if (normalized == null) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit Indian phone number.';
        _result = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final service = ref.read(ownerTenantsFirebaseServiceProvider);
      final data = await service.lookupTenantTrustScoreByPhone(normalized);

      if (!mounted) return;

      setState(() {
        _result = _TrustLookupResult.fromMap(data);
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error.toString());
        _result = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('resource-exhausted') ||
        lower.contains('daily lookup limit')) {
      return 'Daily lookup limit reached (30/day). Please try again tomorrow.';
    }
    if (lower.contains('invalid-argument')) {
      return 'Invalid phone number format.';
    }
    if (lower.contains('permission-denied')) {
      return 'You are not allowed to perform this lookup.';
    }
    return 'Unable to fetch trust score right now. Please try again.';
  }

  String? _normalizeIndianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && RegExp(r'^[6-9]').hasMatch(digits)) {
      return digits;
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(local)) {
        return local;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Trust Score')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Check tenant trust score by phone number',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter 10-digit phone number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _search,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Search Trust Score'),
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.errorContainer,
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _TrustScoreCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _TrustLookupResult {
  const _TrustLookupResult({
    required this.found,
    required this.displayScore,
    required this.statusLabel,
    required this.statusColor,
    required this.message,
    required this.tenantName,
    required this.multipleMatches,
    required this.matchCount,
  });

  final bool found;
  final String displayScore;
  final String statusLabel;
  final Color statusColor;
  final String message;
  final String tenantName;
  final bool multipleMatches;
  final int matchCount;

  double get progressValue {
    final score = int.tryParse(displayScore);
    if (score == null) return 0;
    return (score.clamp(0, 100)) / 100;
  }

  factory _TrustLookupResult.fromMap(Map<String, dynamic> data) {
    final score = data['trustScore'];
    final intScore = score is num ? score.toInt() : null;
    final status = (data['statusLabel'] as String?) ?? 'Unknown';

    return _TrustLookupResult(
      found: data['found'] == true,
      displayScore: intScore == null
          ? (data['displayScore'] as String? ?? 'N/A')
          : '$intScore',
      statusLabel: status,
      statusColor: _statusColor(status),
      message: (data['message'] as String?) ?? '',
      tenantName: (data['tenantName'] as String?) ?? 'Tenant',
      multipleMatches: data['multipleMatches'] == true,
      matchCount: (data['matchCount'] as num?)?.toInt() ?? 0,
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Highly Trusted':
        return AppColors.cFF2ECC71;
      case 'Reliable':
        return AppColors.cFF27AE60;
      case 'Average Risk':
        return AppColors.cFFF1C40F;
      case 'High Risk':
        return AppColors.cFFE67E22;
      case 'Very Risky Tenant':
        return AppColors.cFFE74C3C;
      default:
        return AppColors.grey;
    }
  }
}

class _TrustScoreCard extends StatelessWidget {
  const _TrustScoreCard({required this.result});

  final _TrustLookupResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    result.tenantName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: result.statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    result.statusLabel,
                    style: TextStyle(
                      color: result.statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 110,
                    width: 110,
                    child: CircularProgressIndicator(
                      value: result.progressValue,
                      strokeWidth: 9,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        result.statusColor,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.displayScore,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '/ 100',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (result.multipleMatches)
              Text(
                'Multiple matches found (${result.matchCount}). Showing the best available profile.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (result.message.isNotEmpty)
              Text(
                result.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
