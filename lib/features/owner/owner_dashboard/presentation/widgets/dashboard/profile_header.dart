import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      builder: (context) => _ProfileOverlay(onClose: () => entry.remove()),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownerProfileProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final panelColor =
        Color.lerp(scheme.surface, AppColors.white, isDark ? 0.04 : 0.26) ??
        scheme.surface;

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openProfileCard,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.white.withValues(alpha: isDark ? 0.08 : 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.3 : 0.14),
                blurRadius: 18,
                offset: const Offset(8, 10),
              ),
              BoxShadow(
                color: AppColors.white.withValues(alpha: isDark ? 0.03 : 0.72),
                blurRadius: 16,
                offset: const Offset(-8, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              _AvatarPreview(
                assetPath: profile.avatar.assetPath,
                photoUrl: profile.photoUrl,
              ),
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
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'View Profile Card',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.65),
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
  final String photoUrl;

  const _AvatarPreview({required this.assetPath, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(assetPath, fit: BoxFit.cover);
                },
              )
            : Image.asset(assetPath, fit: BoxFit.cover),
      ),
    );
  }
}

class _ProfileOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const _ProfileOverlay({required this.onClose});

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

    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    _rotation = Tween(
      begin: 0.8,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownerProfileProvider);

    return Material(
      color: AppColors.black.withValues(alpha: 0.45),
      child: GestureDetector(
        onTap: widget.onClose,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
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
                            child: OwnerProfileCard(
                              profile: profile,
                              onClose: widget.onClose,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
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
