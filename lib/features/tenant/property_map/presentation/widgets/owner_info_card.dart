import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerInfoCard extends StatefulWidget {
  final String ownerName;
  final String ownerPhone;
  final String ownerLocation;

  const OwnerInfoCard({
    super.key,
    required this.ownerName,
    required this.ownerPhone,
    required this.ownerLocation,
  });

  @override
  State<OwnerInfoCard> createState() => _OwnerInfoCardState();
}

class _OwnerInfoCardState extends State<OwnerInfoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        final slideY = (1 - t) * 28;
        final angle = (1 - t) * (math.pi / 50);

        return Transform.translate(
          offset: Offset(0, slideY),
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.bottomRight,
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.15),
              theme.colorScheme.tertiary.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 8),
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.ownerName.trim().isEmpty
                          ? 'Owner'
                          : widget.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _DetailChip(
                icon: Icons.phone_rounded,
                label: widget.ownerPhone.trim().isEmpty
                    ? 'Phone not available'
                    : widget.ownerPhone,
                onTap: widget.ownerPhone.trim().isEmpty
                    ? null
                    : () => _openDialer(widget.ownerPhone),
              ),
              const SizedBox(height: 8),
              _DetailChip(
                icon: Icons.location_on_rounded,
                label: widget.ownerLocation.trim().isEmpty
                    ? 'Location not available'
                    : widget.ownerLocation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDialer(String rawPhone) async {
    final phone = rawPhone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DetailChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface.withValues(alpha: 0.72),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.call_made_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
