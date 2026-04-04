import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/core/notifications/push_notification_provider.dart';

class TenantNotificationsScreen extends ConsumerStatefulWidget {
  const TenantNotificationsScreen({super.key});

  @override
  ConsumerState<TenantNotificationsScreen> createState() =>
      _TenantNotificationsScreenState();
}

class _TenantNotificationsScreenState
    extends ConsumerState<TenantNotificationsScreen> {
  bool _enabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final service = ref.read(pushNotificationServiceProvider);
    final enabled = await service.isNotificationsEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _setEnabled(bool value) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _enabled = value;
    });

    try {
      await ref
          .read(pushNotificationServiceProvider)
          .setNotificationsEnabled(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Tenant push notifications enabled.'
                : 'Tenant push notifications disabled.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _enabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update notification preference.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: _enabled,
              onChanged: _isSaving ? null : _setEnabled,
              title: const Text('Push Notifications'),
              subtitle: const Text(
                'Get alerts for nearby cheaper properties and rent updates.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cheaper Nearby Property Alerts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When RentDone detects available properties in your city at lower rent than your current monthly rent, you will get an FCM push notification. Tap the alert to open city search and continue to map discovery flow.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _enabled
                        ? () => context.push('/tenant/city')
                        : null,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open Discovery Flow'),
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
