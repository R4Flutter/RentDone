import 'dart:ui';

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
  bool _isSubmitting = false;

  static const _suggestedCities = <String>[
    'Mumbai',
    'Delhi',
    'Bengaluru',
    'Hyderabad',
    'Chennai',
    'Pune',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (_isSubmitting) return;

    final city = _controller.text.trim();
    if (city.isEmpty) {
      setState(() => _error = 'Please enter a city name');
      return;
    }

    if (city.length < 2) {
      setState(() => _error = 'City name is too short');
      return;
    }

    ref.read(selectedCityProvider.notifier).setCity(city);

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    context.push('/tenant/map?city=$city');
  }

  @override
  Widget build(BuildContext context) {
    final currentCity = ref.watch(selectedCityProvider);

    if (_controller.text.isEmpty && currentCity.trim().isNotEmpty) {
      _controller.text = currentCity;
    }

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xFF070B1B),
                        Color(0xFF112457),
                        Color(0xFF0E1733),
                      ]
                    : const [
                        Color(0xFFF8FBFF),
                        Color(0xFFD9ECFF),
                        Color(0xFFEAF2FF),
                      ],
              ),
            ),
          ),
          const _OrbDecorations(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (dark ? Colors.white : Colors.white)
                              .withValues(alpha: dark ? 0.12 : 0.58),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: dark ? 0.24 : 0.78,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: dark ? 0.28 : 0.14,
                              ),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Find Homes By City',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: onSurface,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter your city to discover live, published properties with vacancies on the interactive map.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: onSurface.withValues(alpha: 0.78),
                                ),
                              ),
                              const SizedBox(height: 22),
                              TextField(
                                controller: _controller,
                                style: theme.textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  labelText: 'City Name',
                                  hintText: 'e.g. Mumbai',
                                  errorText: _error,
                                  prefixIcon: const Icon(
                                    Icons.location_city_rounded,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: dark ? 0.10 : 0.72,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: dark ? 0.22 : 0.9,
                                      ),
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                                onSubmitted: (_) => _continue(),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _suggestedCities.map((city) {
                                  return ActionChip(
                                    label: Text(city),
                                    avatar: const Icon(
                                      Icons.place_outlined,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      _controller.text = city;
                                      _continue();
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed: _isSubmitting ? null : _continue,
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.map_outlined),
                                  label: Text(
                                    _isSubmitting
                                        ? 'Opening Map...'
                                        : 'Explore On Map',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E5BFF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbDecorations extends StatelessWidget {
  const _OrbDecorations();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _GlowOrb(
              size: 220,
              color: dark ? const Color(0xFF5FA8FF) : const Color(0xFF8EC6FF),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -70,
            child: _GlowOrb(
              size: 300,
              color: dark ? const Color(0xFF2E53D9) : const Color(0xFF7CA6FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.52),
            color.withValues(alpha: 0.06),
          ],
        ),
      ),
    );
  }
}
