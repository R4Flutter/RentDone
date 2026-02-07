import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// APP THEME – RENTDONE (PRODUCTION READY, MATERIAL 3)
/// ------------------------------------------------------------
///
/// DESIGN SYSTEM: 60 : 30 : 10
///
/// 60% → Base background
/// 30% → Brand blue surfaces (flat + gradient)
/// 10% → Text / accents
///
/// Rules:
/// - Material 3
/// - Single source of truth
/// - Gradients exposed as tokens (not in ColorScheme)
///
class AppTheme {
  AppTheme._();

  // ============================================================
  // BRAND CORE
  // ============================================================

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color nearBlack   = Color(0xFF0F172A);
  static const Color pureWhite   = Color(0xFFFFFFFF);

  static const Color errorRed     = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFF59E0B);

  // ============================================================
  // UNIVERSAL BLUE SYSTEM (30%)
  // ============================================================

  /// Exact logo blues
  static const Color blueLight = Color.fromARGB(255, 47, 107, 255); // #2F6BFF
  static const Color blueMain  = Color.fromARGB(255, 21, 74, 246);  // #154AF6
  static const Color blueDark  = Color.fromARGB(255, 5, 18, 174);   // #0512AE

  /// 🔥 UNIVERSAL GRADIENT (USE FOR CARDS / GLASS / HERO)
  static const LinearGradient blueSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromARGB(180, 47, 107, 255),
      Color.fromARGB(160, 21, 74, 246),
      Color.fromARGB(140, 5, 18, 174),
    ],
  );

  /// Flat fallback (ThemeData safe)
  static const Color blueSurface = blueMain;

  // ============================================================
  // LIGHT THEME (60 : 30 : 10)
  // ============================================================

  static final Color lightBlueSurface =
      primaryBlue.withValues(alpha: 0.08);

  static final Color lightBlueSurfaceStrong =
      primaryBlue.withValues(alpha: 0.12);

  // ============================================================
  // DARK THEME (60 : 30 : 10)
  // ============================================================

  static const Color darkBackground = Color(0xFF020B14); // 60%
  static const Color darkSurface    = blueSurface;       // 30%
  static const Color darkText       = Color(0xFFE6F1FF);  // 10%

  // ============================================================
  // COLOR SCHEMES (COLOR ONLY)
  // ============================================================

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryBlue,
    secondary: primaryBlue,
    surface: pureWhite,
    onSurface: nearBlack,
    onPrimary: pureWhite,
    onSecondary: pureWhite,
    error: errorRed,
    onError: pureWhite,
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryBlue,
    secondary: primaryBlue,
    surface: darkBackground,
    onSurface: darkText,
    onPrimary: darkText,
    onSecondary: darkText,
    error: errorRed,
    onError: darkText,
  );

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    scaffoldBackgroundColor: pureWhite,
    textTheme: _textTheme(nearBlack),

    appBarTheme: AppBarTheme(
      backgroundColor: lightBlueSurface,
      foregroundColor: nearBlack,
      elevation: 0,
      centerTitle: true,
    ),

    cardTheme: CardThemeData(
      color: lightBlueSurfaceStrong,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );

  // ============================================================
  // DARK THEME
  // ============================================================

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _darkColorScheme,
    scaffoldBackgroundColor: darkBackground,
    textTheme: _textTheme(darkText),

    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: darkText,
      elevation: 0,
      centerTitle: true,
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );

  // ============================================================
  // TEXT SYSTEM
  // ============================================================

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: _textStyle(32, FontWeight.bold, color),
      displayMedium: _textStyle(26, FontWeight.w600, color),
      titleLarge: _textStyle(18, FontWeight.w600, color),
      bodyLarge: _textStyle(16, FontWeight.normal, color),
      bodyMedium: _textStyle(14, FontWeight.normal, color),
      labelLarge: _textStyle(14, FontWeight.w600, color),
    );
  }

  static TextStyle _textStyle(
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
