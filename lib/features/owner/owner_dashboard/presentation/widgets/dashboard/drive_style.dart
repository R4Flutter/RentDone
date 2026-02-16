import 'package:flutter/material.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/sidebar_item.dart';

class DriveStyleTile extends StatefulWidget {
  const DriveStyleTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<DriveStyleTile> createState() => _DriveStyleTileState();
}

class _DriveStyleTileState extends State<DriveStyleTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final Color baseBg = scheme.surface;
    final Color textColor = scheme.onSurface;
    final Color accent = scheme.primary;
    final bool raised = widget.selected || _pressed;
    final Color selectedTint =
        Color.lerp(baseBg, accent, isDark ? 0.18 : 0.08) ?? baseBg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          scale: _pressed ? 1.02 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: baseBg,
              gradient: widget.selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [selectedTint, baseBg],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected
                    ? accent.withValues(alpha: 0.35)
                    : textColor.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: raised ? 26 : 18,
                  offset: Offset(0, raised ? 14 : 10),
                ),
                BoxShadow(
                  color:
                      Colors.white.withValues(alpha: isDark ? 0.06 : 0.7),
                  blurRadius: 12,
                  offset: const Offset(-4, -4),
                ),
                if (widget.selected || _pressed)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.item.icon,
                  size: 20,
                  color: widget.selected
                      ? accent
                      : textColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          widget.selected ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
