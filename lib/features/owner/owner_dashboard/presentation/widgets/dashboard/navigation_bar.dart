
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_layout_provider.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/widgets/dashboard/user_menu.dart';

class OwnerTopNavBar extends ConsumerStatefulWidget {
  const OwnerTopNavBar({super.key});

  static const _height = 64.0;

  @override
  ConsumerState<OwnerTopNavBar> createState() => _OwnerTopNavBarState();
}

class _OwnerTopNavBarState extends ConsumerState<OwnerTopNavBar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: OwnerTopNavBar._height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              // ✅ SAME BLUE GRADIENT AS CARDS
              gradient: AppTheme.blueNavGradient,

              // ✅ THEME-SAFE BORDER
              border: Border(
                bottom: BorderSide(
                  color: colors.onSurface.withValues(alpha:0.12),
                ),
              ),

              // ✅ THEME-SAFE HOVER SHADOW
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: colors.onSurface.withValues(alpha:0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // ☰ LEFT – HAMBURGER
                _IconHover(
                  child: IconButton(
                    tooltip: 'Toggle sidebar',
                    icon: Icon(Icons.menu, color: colors.onPrimary),
                    onPressed: () {
                      ref
                          .read(dashboardLayoutProvider.notifier)
                          .toggleSidebar();
                    },
                  ),
                ),

                // CENTER – LOGO + APP NAME
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // ✅ NO WHITE OVERLAY
                            color: colors.onPrimary.withValues(alpha:0.12),
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            size: 18,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'RentApp',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // RIGHT – USER / ACCOUNT
                const UserMenu(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconHover extends StatefulWidget {
  final Widget child;
  const _IconHover({required this.child});

  @override
  State<_IconHover> createState() => _IconHoverState();
}

class _IconHoverState extends State<_IconHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: widget.child,
      ),
    );
  }
}