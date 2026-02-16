import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/owner_profile_card.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';

class ProfileHeader extends ConsumerStatefulWidget {
  const ProfileHeader({super.key});

  @override
  ConsumerState<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<ProfileHeader> {
  final LayerLink _layerLink = LayerLink();

  void _openProfileCard() {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ProfileOverlay(
        onClose: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownerProfileProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openProfileCard,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppTheme.blueSurfaceGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _AvatarPreview(assetPath: profile.avatar.assetPath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'View Profile Card',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onPrimary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String assetPath;

  const _AvatarPreview({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(assetPath, fit: BoxFit.cover),
      ),
    );
  }
}

class _ProfileOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const _ProfileOverlay({
    required this.onClose,
  });

  @override
  ConsumerState<_ProfileOverlay> createState() => _ProfileOverlayState();
}

class _ProfileOverlayState extends ConsumerState<_ProfileOverlay>
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
    final profile = ref.watch(ownerProfileProvider);

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: GestureDetector(
        onTap: widget.onClose,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: () {},
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
                        child: OwnerProfileCard(profile: profile),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
