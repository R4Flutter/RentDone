import 'package:flutter/material.dart';
import 'package:rentdone/features/owner/presentation/ui_models/sidebar_item.dart';

class DriveStyleTile extends StatelessWidget {
  const DriveStyleTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool selected;
  final VoidCallback onTap;

  static const _primaryColor = Color(0xFF6D28D9);
  static const _selectedBg = Color(0xFFEDE9FE);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? _selectedBg : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: selected ? _primaryColor : Colors.black54,
            ),
            const SizedBox(width: 14),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                color:
                    selected ? _primaryColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}