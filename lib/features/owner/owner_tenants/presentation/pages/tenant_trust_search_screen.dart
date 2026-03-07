import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_tenants/di/owner_tenants_di.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/entities/tenant_trust_lookup.dart';

class TenantTrustSearchScreen extends ConsumerStatefulWidget {
  const TenantTrustSearchScreen({super.key});

  @override
  ConsumerState<TenantTrustSearchScreen> createState() =>
      _TenantTrustSearchScreenState();
}

class _TenantTrustSearchScreenState
    extends ConsumerState<TenantTrustSearchScreen> {
  final _phoneController = TextEditingController();
  bool _isSearching = false;
  String? _errorMessage;
  List<TenantTrustLookup> _results = const [];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final input = _phoneController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Enter tenant phone number';
        _results = const [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(ownerTenantsFirebaseServiceProvider);
      final data = await service.searchTenantTrustByPhone(input);
      if (!mounted) return;
      setState(() {
        _results = data;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _results = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Trust Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Search by phone number',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Enter tenant phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _isSearching ? null : _search,
                icon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 8),
          ],
          if (!_isSearching && _results.isEmpty && _errorMessage == null)
            Text(
              'No result yet. Enter a phone number to view trust profile.',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
          for (final item in _results) ...[
            const SizedBox(height: 10),
            _TrustProfileCard(item: item),
          ],
        ],
      ),
    );
  }
}

class _TrustProfileCard extends StatelessWidget {
  final TenantTrustLookup item;

  const _TrustProfileCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(item.trustScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.tenantName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    item.trustBadge,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statRow('Trust Score', '${item.trustScore}/100'),
            _statRow('On-time Payments', '${item.onTimePaymentRate}%'),
            _statRow('Late Payments', '${item.latePaymentRate}%'),
            _statRow('Tenure', '${item.tenureYears} years'),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _badgeColor(int score) {
    final clamped = score.clamp(0, 100);
    if (clamped >= 90) return Colors.green;
    if (clamped >= 70) return Colors.blue;
    if (clamped >= 50) return Colors.amber.shade800;
    if (clamped >= 20) return Colors.orange;
    return Colors.red;
  }
}
