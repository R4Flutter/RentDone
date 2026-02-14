import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String uid;
  final String? name;
  final String? phone;
  final String? email;
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
      uid: map['uid'] ?? '',
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
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

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isProfileComplete': isProfileComplete,
    };
  }

  AuthUser copyWith({
    String? uid,
    String? name,
    String? phone,
    String? role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isProfileComplete,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }

  @override
  String toString() => 'AuthUser(uid: $uid, name: $name, phone: $phone)';
}
