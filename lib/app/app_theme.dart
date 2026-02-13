import 'package:flutter/material.dart';

/// =============================================================
/// APP THEME – RENTDONE (INDUSTRY GRADE, MATERIAL 3)
/// =============================================================
///
/// DESIGN SYSTEM: 60 / 30 / 10
///
/// LIGHT MODE
/// 60% → White background
/// 30% → Blue gradient surfaces
/// 10% → Near-black text
///
/// DARK MODE
/// 60% → Near-black background
/// 30% → Blue gradient surfaces
/// 10% → White text
///
/// RULES:
/// - No gradients in ColorScheme
/// - No blue text ever
/// - Widgets must read from Theme.of(context)
///
class AppTheme {
  AppTheme._();

  // =============================================================
  // BRAND CORE
  // =============================================================

  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color nearBlack = Color(0xFF0F172A);

  static const Color primaryBlue = Color(0xFF2563EB);

  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFDC2626);

  // =============================================================
  // BLUE SYSTEM (30% — SURFACES ONLY)
  // =============================================================

  static const LinearGradient blueSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromARGB(180, 47, 107, 255),
      Color.fromARGB(160, 21, 74, 246),
      Color.fromARGB(140, 5, 18, 174),
    ],
  );
  static const LinearGradient blueNavGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color.fromARGB(200, 47, 107, 255), // slightly stronger
    Color.fromARGB(180, 21, 74, 246),
    Color.fromARGB(160, 5, 18, 174),
  ],
);

  // =============================================================
  // COLOR SCHEMES (TEXT + SEMANTICS ONLY)
  // =============================================================

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    surface: pureWhite,      // 60%
    onSurface: nearBlack,    // 10%
    primary: primaryBlue,
    secondary: primaryBlue,
    onPrimary: pureWhite,
    onSecondary: pureWhite,
    error: errorRed,
    onError: pureWhite,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    surface: nearBlack,      // 60%
    onSurface: pureWhite,    // 10%
    primary: primaryBlue,
    secondary: primaryBlue,
    onPrimary: pureWhite,
    onSecondary: pureWhite,
    error: errorRed,
    onError: pureWhite,
  );

  // =============================================================
  // LIGHT THEME
  // =============================================================

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightScheme,

    scaffoldBackgroundColor: pureWhite,

    textTheme: _textTheme(nearBlack),

    appBarTheme: const AppBarTheme(
      backgroundColor: pureWhite,
      foregroundColor: nearBlack,
      elevation: 0,
      centerTitle: true,
    ),

    cardTheme: CardThemeData(
      color: pureWhite, // neutral card, gradients applied manually
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: nearBlack.withValues(alpha :0.1),
      thickness: 1,
    ),
  );

  // =============================================================
  // DARK THEME
  // =============================================================

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkScheme,

    scaffoldBackgroundColor: nearBlack,

    textTheme: _textTheme(pureWhite),

    appBarTheme: const AppBarTheme(
      backgroundColor: nearBlack,
      foregroundColor: pureWhite,
      elevation: 0,
      centerTitle: true,
    ),

    cardTheme: CardThemeData(
      color: nearBlack,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: pureWhite.withValues(alpha: 0.12),
      thickness: 1,
    ),
  );

  // =============================================================
  // TYPOGRAPHY
  // =============================================================

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: _style(32, FontWeight.bold, color),
      displayMedium: _style(26, FontWeight.w600, color),
      titleLarge: _style(18, FontWeight.w600, color),
      bodyLarge: _style(16, FontWeight.normal, color),
      bodyMedium: _style(14, FontWeight.normal, color),
      labelLarge: _style(14, FontWeight.w600, color),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color,
  ) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.3,
    );
  }
}