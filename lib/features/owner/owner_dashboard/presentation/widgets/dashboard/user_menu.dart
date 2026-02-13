import 'package:flutter/material.dart';

class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        // later: showMenu / bottom sheet / dialog
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: const [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/150',
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.expand_more,
              size: 20,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}