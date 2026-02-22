import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/tenant/property_map/presentation/providers/tenant_map_providers.dart';

class TenantCityEntryScreen extends ConsumerStatefulWidget {
  const TenantCityEntryScreen({super.key});

  @override
  ConsumerState<TenantCityEntryScreen> createState() =>
      _TenantCityEntryScreenState();
}

class _TenantCityEntryScreenState extends ConsumerState<TenantCityEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final city = _controller.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'Please enter a city name');
      return;
    }

    ref.read(selectedCityProvider.notifier).state = city;
    setState(() => _error = null);

    context.go('/tenant/map?city=$city');
  }

  @override
  Widget build(BuildContext context) {
    final currentCity = ref.watch(selectedCityProvider);

    if (_controller.text.isEmpty && currentCity.trim().isNotEmpty) {
      _controller.text = currentCity;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select City'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'City name',
                hintText: 'e.g. Mumbai',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continue(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _continue,
                child: const Text('Show Properties'),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'We will show available properties on the map for the city you enter.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}