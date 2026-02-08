import 'package:flutter/material.dart';

class DashboardError extends StatelessWidget {
  const DashboardError({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          SizedBox(height: 12),
          Text(
            'Failed to load dashboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Please check your connection and try again',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}