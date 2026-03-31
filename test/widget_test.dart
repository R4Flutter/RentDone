import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentdone/app/app_theme.dart';

void main() {
  test('App themes are configured', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(AppTheme.lightTheme.useMaterial3, isTrue);
    expect(AppTheme.darkTheme.useMaterial3, isTrue);
  });
}
