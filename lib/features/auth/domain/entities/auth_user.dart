import 'package:flutter/material.dart';

@immutable
class AuthUser {
  final String id;
  final String phone;
  final String? name;

  const AuthUser({
    required this.id,
    required this.phone,
    this.name,
  });
}