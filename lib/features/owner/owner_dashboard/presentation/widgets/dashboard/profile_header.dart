import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final LayerLink _layerLink = LayerLink();

  void _openProfileCard() {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ProfileOverlay(
        layerLink: _layerLink,
        onClose: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openProfileCard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(
                  'https://i.pravatar.cc/150',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raj Naik',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'raj@gmail.com',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                color: scheme.onSurface
                    .withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _ProfileOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final VoidCallback onClose;

  const _ProfileOverlay({
    required this.layerLink,
    required this.onClose,
  });

  @override
  State<_ProfileOverlay> createState() => _ProfileOverlayState();
}

class _ProfileOverlayState extends State<_ProfileOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _rotation = Tween(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.black.withValues(alpha:0.4),
      child: GestureDetector(
        onTap: widget.onClose,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scale.value,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_rotation.value),
                  child: _profileCard(theme),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileCard(ThemeData theme) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 40),
          const SizedBox(height: 20),
          Text(
            "Raj Naik",
            style: theme.textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            "raj@gmail.com",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Divider(
            color: theme.colorScheme.onSurface
                .withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text("Sunshine Residency"),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text("+91 9876543210"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.onClose,
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}