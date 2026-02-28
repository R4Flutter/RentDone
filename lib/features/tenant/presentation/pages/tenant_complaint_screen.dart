import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';

import 'package:rentdone/features/tenant/domain/entities/tenant_dashboard_summary.dart';
import 'package:rentdone/features/tenant/presentation/providers/tenant_dashboard_provider.dart';
import 'package:rentdone/features/tenant/presentation/widgets/tenant_glass.dart';

class TenantComplaintScreen extends ConsumerStatefulWidget {
  const TenantComplaintScreen({super.key});

  @override
  ConsumerState<TenantComplaintScreen> createState() =>
      _TenantComplaintScreenState();
}

class _TenantComplaintScreenState extends ConsumerState<TenantComplaintScreen> {
  static const _categories = [
    'Electrical',
    'Plumbing',
    'Structural',
    'Maintenance',
    'Other',
  ];

  final _descriptionController = TextEditingController();
  String _selectedCategory = _categories.first;
  Timer? _syncRetryTimer;
  int _syncAttempts = 0;

  static const _maxSyncAttempts = 10;
  static const _syncRetryInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _stopAutoSync();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(tenantDashboardProvider);
    final isSubmitting = ref.watch(complaintSubmittingProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (summary) {
        if (summary.tenantId.isEmpty) {
          _startAutoSyncIfNeeded();
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text(
                    'Tenant profile sync is in progress. Complaint submission will open shortly.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        _stopAutoSync();

        return Container(
          color: AppTheme.nearBlack,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Complaint Box',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TenantGlassCard(
                accent: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raise an Issue',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track maintenance and service requests quickly.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TenantGlassCard(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  dropdownColor: AppTheme.nearBlack,
                  style: const TextStyle(color: Colors.white),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                  decoration: tenantGlassInputDecoration(
                    context,
                    label: 'Issue Category',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TenantGlassCard(
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: tenantGlassInputDecoration(
                    context,
                    label: 'Complaint Description',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => _submitComplaint(summary),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: Colors.white,
                  ),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: const Text('Submit Complaint'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startAutoSyncIfNeeded() {
    if (_syncRetryTimer != null || !mounted) {
      return;
    }

    _syncAttempts = 0;
    _syncRetryTimer = Timer.periodic(_syncRetryInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      final hasTenantId = ref
          .read(tenantDashboardProvider)
          .maybeWhen(
            data: (summary) => summary.tenantId.isNotEmpty,
            orElse: () => false,
          );

      if (hasTenantId) {
        timer.cancel();
        _syncRetryTimer = null;
        return;
      }

      _syncAttempts += 1;
      ref.invalidate(tenantDashboardProvider);

      if (_syncAttempts >= _maxSyncAttempts) {
        timer.cancel();
        _syncRetryTimer = null;
      }
    });
  }

  void _stopAutoSync() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  Future<void> _submitComplaint(TenantDashboardSummary summary) async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complaint description')),
      );
      return;
    }

    try {
      await submitComplaint(
        ref,
        summary: summary,
        description: description,
        category: _selectedCategory,
      );
      if (!mounted) return;
      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint submitted and WhatsApp opened'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
    }
  }
}
