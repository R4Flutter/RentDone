import 'package:flutter/material.dart';

class AlertsPanel extends StatelessWidget {
  const AlertsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
     
      child: Column(
        children: const [
          _AlertTile(
            title: 'Shop A12',
            subtitle: 'Late payment · ₹300 fine',
            color: Colors.red,
          ),
          SizedBox(height: 12),
          _AlertTile(
            title: 'Tenant Request',
            subtitle: 'Approval pending',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}