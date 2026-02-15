import 'package:flutter/material.dart';

@immutable
class AuthUser {
  final String uid;
  final String? name;
  final String? phone;
  final String? role; // 'owner' or 'tenant'
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool isProfileComplete;

  const AuthUser({
    required this.uid,
    this.name,
    this.phone,
    this.role,
    this.createdAt,
    this.lastLoginAt,
    this.isProfileComplete = false,
  });

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      uid: map['uid'] ?? ' ',
      name: map['name'],
      phone: map['phone'],
      role: map['role'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
      isProfileComplete: map['isProfileComplete'] ?? false,
    );
  }
}
