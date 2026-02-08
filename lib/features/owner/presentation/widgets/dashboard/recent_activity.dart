import 'package:flutter/material.dart';

class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
  
      child: Column(
        children: const [
          _ActivityTile('Payment received from Flat 203'),
          _ActivityTile('New tenant added'),
          _ActivityTile('Maintenance request submitted'),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String text;
  const _ActivityTile(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}