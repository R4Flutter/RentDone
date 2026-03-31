import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color nearBlack = Color(0xFF0F172A);

  static const Color darkPrimaryBlue = Color(0xFF3B82F6);
  static const Color lightPrimaryBlue = Color(0xFF3B82F6);
  static const Color primaryBlue = darkPrimaryBlue;
  static const Color primaryHoverBlue = Color(0xFF2563EB);
  static const Color primarySoftBlue = Color(0xFFDBEAFE);

  // Liquid manage-properties palette
  static const Color liquidPrimaryStart = Color(0xFF4F8CFF);
  static const Color liquidPrimaryEnd = Color(0xFF2563EB);
  static const Color liquidBackgroundLightStart = Color(0xFFF3F6FB);
  static const Color liquidBackgroundLightEnd = Color(0xFFE6ECF7);
  static const Color liquidTextPrimaryLight = Color(0xFF111827);
  static const Color liquidTextSecondaryLight = Color(0xFF6B7280);
  static const Color liquidShadow = Color(0x262040AF);

  // Semantics
  static const Color successGreen = Color(0xFF22C55E);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF38BDF8);
  static const Color tenantTeal = Color(0xFF14B8A6);

  // Light system
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark system
  static const Color darkBackground = Color(0xFF020617);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF475569);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Shared gradients for premium glass surfaces
  static const LinearGradient blueSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x663B82F6), Color(0x333B82F6)],
  );

  static const LinearGradient blueNavGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x803B82F6), Color(0x403B82F6)],
  );

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    surface: lightSurface,
    onSurface: lightTextPrimary,
    primary: lightPrimaryBlue,
    secondary: tenantTeal,
    onPrimary: pureWhite,
    onSecondary: pureWhite,
    error: errorRed,
    onError: pureWhite,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    surface: darkSurface,
    onSurface: darkTextPrimary,
    primary: darkPrimaryBlue,
    secondary: tenantTeal,
    onPrimary: pureWhite,
    onSecondary: pureWhite,
    error: errorRed,
    onError: pureWhite,
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _lightScheme,

    fontFamily: 'Inter',
    scaffoldBackgroundColor: lightBackground,
    textTheme: _textTheme(lightTextPrimary),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      centerTitle: true,
    ),

    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.large),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.input),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.input),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.input),
        borderSide: const BorderSide(color: lightPrimaryBlue, width: 1.5),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightPrimaryBlue,
        foregroundColor: pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnerThemeShape.medium),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OwnerThemeSpacing.lg,
          vertical: OwnerThemeSpacing.md,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: lightTextPrimary,
        side: const BorderSide(color: lightBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnerThemeShape.medium),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      backgroundColor: Color.lerp(lightCard, lightPrimaryBlue, 0.08),
      contentTextStyle: _textTheme(lightTextPrimary).bodyMedium?.copyWith(
        color: lightTextPrimary,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: lightPrimaryBlue,
      disabledActionTextColor: lightTextMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightBorder),
      ),
    ),

    dividerTheme: DividerThemeData(color: lightDivider, thickness: 1),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _darkScheme,

    fontFamily: 'Inter',
    scaffoldBackgroundColor: darkBackground,
    textTheme: _textTheme(darkTextPrimary),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: true,
    ),

    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.large),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.input),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.input),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OwnerThemeShape.input),
        borderSide: const BorderSide(color: darkPrimaryBlue, width: 1.5),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryBlue,
        foregroundColor: pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnerThemeShape.medium),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OwnerThemeSpacing.lg,
          vertical: OwnerThemeSpacing.md,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkTextPrimary,
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OwnerThemeShape.medium),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      backgroundColor: Color.lerp(darkCard, darkPrimaryBlue, 0.24),
      contentTextStyle: _textTheme(darkTextPrimary).bodyMedium?.copyWith(
        color: darkTextPrimary,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: AppColors.cFF60A5FA,
      disabledActionTextColor: darkTextMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkBorder),
      ),
    ),

    dividerTheme: DividerThemeData(color: darkDivider, thickness: 1),
  );

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: _style(32, FontWeight.w700, color, 1.2),
      displayMedium: _style(24, FontWeight.w700, color, 1.2),
      displaySmall: _style(20, FontWeight.w600, color, 1.2),
      titleLarge: _style(20, FontWeight.w600, color, 1.2),
      titleMedium: _style(18, FontWeight.w600, color, 1.2),
      titleSmall: _style(16, FontWeight.w600, color, 1.2),
      bodyLarge: _style(14, FontWeight.w500, color, 1.5),
      bodyMedium: _style(14, FontWeight.w400, color, 1.5),
      bodySmall: _style(12, FontWeight.w400, color, 1.7),
      labelLarge: _style(14, FontWeight.w600, color, 1.5),
      labelMedium: _style(12, FontWeight.w500, color, 1.5),
      labelSmall: _style(12, FontWeight.w500, color, 1.5),
    );
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color,
    double lineHeight,
  ) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: lineHeight,
    );
  }
}

class OwnerThemeSpacing {
  OwnerThemeSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class OwnerThemeShape {
  OwnerThemeShape._();

  static const double small = 8;
  static const double input = 10;
  static const double medium = 12;
  static const double large = 16;
  static const double xl = 20;
}

class OwnerThemeGlass {
  OwnerThemeGlass._();

  static const double blur = 12;
  static const double backgroundOpacity = 0.6;
  static const double borderOpacity = 0.06;
}

class OwnerDashboardTone {
  final Color iconBackground;
  final Color iconColor;
  final Color progressColor;

  const OwnerDashboardTone({
    required this.iconBackground,
    required this.iconColor,
    required this.progressColor,
  });
}

class OwnerDashboardColors {
  OwnerDashboardColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color brandPrimary(BuildContext context) => AppTheme.darkPrimaryBlue;

  static Color brandPrimaryHover(BuildContext context) =>
      AppTheme.primaryHoverBlue;

  static Color brandPrimarySoft(BuildContext context) =>
      AppTheme.primarySoftBlue;

  static Color pageBackground(BuildContext context) =>
      isDark(context) ? AppTheme.darkBackground : AppTheme.lightBackground;

  static Color cardBackground(BuildContext context) =>
      isDark(context) ? AppTheme.darkCard : AppTheme.lightCard;

  static Color elevatedBackground(BuildContext context) =>
      isDark(context) ? AppTheme.darkSurface : AppTheme.lightSurface;

  static Color border(BuildContext context) =>
      isDark(context) ? AppTheme.darkBorder : AppTheme.lightBorder;

  static Color divider(BuildContext context) =>
      isDark(context) ? AppTheme.darkDivider : AppTheme.lightDivider;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

  static Color textSecondary(BuildContext context) => isDark(context)
      ? AppTheme.darkTextSecondary
      : AppTheme.lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

  static Color iconPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

  static Color iconSecondary(BuildContext context) => isDark(context)
      ? AppTheme.darkTextSecondary
      : AppTheme.lightTextSecondary;

  static Color navActive(BuildContext context) => AppTheme.darkPrimaryBlue;

  static Color navInactive(BuildContext context) => isDark(context)
      ? AppTheme.darkTextSecondary
      : AppTheme.lightTextSecondary;

  // Shared owner-page background system to keep dashboard look globally consistent.
  static LinearGradient ownerPageBackgroundGradient(BuildContext context) {
    final base = pageBackground(context);
    final tinted =
        Color.lerp(
          base,
          brandPrimary(context),
          isDark(context) ? 0.08 : 0.05,
        ) ??
        base;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, tinted],
    );
  }

  static Color ownerTopBlobColor(BuildContext context) =>
      brandPrimary(context).withValues(alpha: isDark(context) ? 0.16 : 0.10);

  static Color ownerBottomBlobColor(BuildContext context) =>
      brandPrimary(context).withValues(alpha: isDark(context) ? 0.12 : 0.08);

  static LinearGradient managePropertiesBackgroundGradient(
    BuildContext context,
  ) {
    if (isDark(context)) {
      return ownerPageBackgroundGradient(context);
    }

    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.liquidBackgroundLightStart,
        AppTheme.liquidBackgroundLightEnd,
      ],
    );
  }

  static LinearGradient managePropertiesAccentGradient(BuildContext context) =>
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.liquidPrimaryStart, AppTheme.liquidPrimaryEnd],
      );

  static Color managePropertiesHeaderPrimary(BuildContext context) =>
      isDark(context) ? textPrimary(context) : AppTheme.liquidTextPrimaryLight;

  static Color managePropertiesHeaderSecondary(BuildContext context) =>
      isDark(context)
      ? textSecondary(context)
      : AppTheme.liquidTextSecondaryLight;

  static Color managePropertiesPillTextColor(BuildContext context) =>
      isDark(context) ? textPrimary(context) : AppTheme.liquidTextPrimaryLight;

  static Color managePropertiesPillBackground(BuildContext context) =>
      AppTheme.pureWhite.withValues(alpha: isDark(context) ? 0.22 : 0.45);

  static Color managePropertiesPillBorder(BuildContext context) =>
      AppTheme.pureWhite.withValues(alpha: isDark(context) ? 0.32 : 0.55);

  static Color managePropertiesCardTint(BuildContext context) =>
      isDark(context) ? brandPrimary(context) : AppTheme.liquidPrimaryStart;

  static Color managePropertiesShadowColor(BuildContext context) =>
      AppTheme.liquidShadow.withValues(alpha: isDark(context) ? 0.22 : 0.15);

  static Color managePropertiesActionColor(BuildContext context) =>
      AppTheme.liquidPrimaryEnd;

  static OwnerDashboardTone propertiesTone(BuildContext context) {
    if (isDark(context)) {
      return const OwnerDashboardTone(
        iconBackground: Color(0x2238BDF8),
        iconColor: Color(0xFF38BDF8),
        progressColor: Color(0xFF38BDF8),
      );
    }

    return const OwnerDashboardTone(
      iconBackground: Color(0x1F38BDF8),
      iconColor: Color(0xFF38BDF8),
      progressColor: Color(0xFF38BDF8),
    );
  }

  static OwnerDashboardTone tenantsTone(BuildContext context) {
    if (isDark(context)) {
      return const OwnerDashboardTone(
        iconBackground: Color(0x2214B8A6),
        iconColor: Color(0xFF14B8A6),
        progressColor: Color(0xFF14B8A6),
      );
    }

    return const OwnerDashboardTone(
      iconBackground: Color(0x1F14B8A6),
      iconColor: Color(0xFF14B8A6),
      progressColor: Color(0xFF14B8A6),
    );
  }

  static OwnerDashboardTone collectedTone(BuildContext context) {
    if (isDark(context)) {
      return const OwnerDashboardTone(
        iconBackground: Color(0x2222C55E),
        iconColor: Color(0xFF22C55E),
        progressColor: Color(0xFF22C55E),
      );
    }

    return const OwnerDashboardTone(
      iconBackground: Color(0x1F22C55E),
      iconColor: Color(0xFF22C55E),
      progressColor: Color(0xFF22C55E),
    );
  }

  static OwnerDashboardTone pendingTone(BuildContext context) {
    if (isDark(context)) {
      return const OwnerDashboardTone(
        iconBackground: Color(0x22F59E0B),
        iconColor: Color(0xFFF59E0B),
        progressColor: Color(0xFFF59E0B),
      );
    }

    return const OwnerDashboardTone(
      iconBackground: Color(0x1FF59E0B),
      iconColor: Color(0xFFF59E0B),
      progressColor: Color(0xFFF59E0B),
    );
  }

  static OwnerDashboardTone cashTone(BuildContext context) {
    if (isDark(context)) {
      return const OwnerDashboardTone(
        iconBackground: Color(0x2222C55E),
        iconColor: Color(0xFF22C55E),
        progressColor: Color(0xFF22C55E),
      );
    }

    return const OwnerDashboardTone(
      iconBackground: Color(0x1F22C55E),
      iconColor: Color(0xFF22C55E),
      progressColor: Color(0xFF22C55E),
    );
  }

  static OwnerDashboardTone upiTone(BuildContext context) {
    if (isDark(context)) {
      return const OwnerDashboardTone(
        iconBackground: Color(0x2238BDF8),
        iconColor: Color(0xFF38BDF8),
        progressColor: Color(0xFF3B82F6),
      );
    }

    return const OwnerDashboardTone(
      iconBackground: Color(0x1F38BDF8),
      iconColor: Color(0xFF38BDF8),
      progressColor: Color(0xFF3B82F6),
    );
  }

  static Color activityCardBackground(BuildContext context) =>
      isDark(context) ? AppTheme.darkSurface : AppTheme.lightCard;

  static Color activityCardBorder(BuildContext context) =>
      isDark(context) ? AppTheme.darkBorder : AppTheme.lightBorder;
}

class AppColors {
  AppColors._();

  static const MaterialColor amber = Colors.amber;
  static const Color black = Colors.black;
  static const Color black12 = Colors.black12;
  static const Color black26 = Colors.black26;
  static const Color black54 = Colors.black54;
  static const Color black87 = Colors.black87;
  static const MaterialColor blue = Colors.blue;
  static const MaterialColor green = Colors.green;
  static const MaterialColor grey = Colors.grey;
  static const MaterialColor orange = Colors.orange;
  static const MaterialColor red = Colors.red;
  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color white12 = Colors.white12;
  static const Color white38 = Colors.white38;
  static const Color white54 = Colors.white54;
  static const Color white70 = Colors.white70;

  static const Color cFF052E16 = Color(0xFF052E16);
  static const Color cFF059669 = Color(0xFF059669);
  static const Color cFF064E3B = Color(0xFF064E3B);
  static const Color cFF020617 = Color(0xFF020617);
  static const Color cFF0A0E27 = Color(0xFF0A0E27);
  static const Color cFF0B1220 = Color(0xFF0B1220);
  static const Color cFF0E1A2B = Color(0xFF0E1A2B);
  static const Color cFF0E7A5F = Color(0xFF0E7A5F);
  static const Color cFF0F172A = Color(0xFF0F172A);
  static const Color cFF0F1C2E = Color(0xFF0F1C2E);
  static const Color cFF101A2D = Color(0xFF101A2D);
  static const Color cFF10B981 = Color(0xFF10B981);
  static const Color cFF111827 = Color(0xFF111827);
  static const Color cFF111C30 = Color(0xFF111C30);
  static const Color cFF141F35 = Color(0xFF141F35);
  static const Color cFF151E36 = Color(0xFF151E36);
  static const Color cFF152238 = Color(0xFF152238);
  static const Color cFF16263C = Color(0xFF16263C);
  static const Color cFF162640 = Color(0xFF162640);
  static const Color cFF16A34A = Color(0xFF16A34A);
  static const Color cFF17263D = Color(0xFF17263D);
  static const Color cFF14B8A6 = Color(0xFF14B8A6);
  static const Color cFF1A1B2F = Color(0xFF1A1B2F);
  static const Color cFF1A1F3A = Color(0xFF1A1F3A);
  static const Color cFF1A8C6E = Color(0xFF1A8C6E);
  static const Color cFF1B2B49 = Color(0xFF1B2B49);
  static const Color cFF1B2E4D = Color(0xFF1B2E4D);
  static const Color cFF1C2D52 = Color(0xFF1C2D52);
  static const Color cFF1E293B = Color(0xFF1E293B);
  static const Color cFF1E3A8A = Color(0xFF1E3A8A);
  static const Color cFF1F2937 = Color(0xFF1F2937);
  static const Color cFF22C55E = Color(0xFF22C55E);
  static const Color cFF22D3EE = Color(0xFF22D3EE);
  static const Color cFF2563EB = Color(0xFF2563EB);
  static const Color cFF27AE60 = Color(0xFF27AE60);
  static const Color cFF2ECC71 = Color(0xFF2ECC71);
  static const Color cFF2F1D46 = Color(0xFF2F1D46);
  static const Color cFF34D399 = Color(0xFF34D399);
  static const Color cFF38BDF8 = Color(0xFF38BDF8);
  static const Color cFF3B82F6 = Color(0xFF3B82F6);
  static const Color cFF3FE0FF = Color(0xFF3FE0FF);
  static const Color cFF4285F4 = Color(0xFF4285F4);
  static const Color cFF451A03 = Color(0xFF451A03);
  static const Color cFF4ADE80 = Color(0xFF4ADE80);
  static const Color cFF4F7CFF = Color(0xFF4F7CFF);
  static const Color cFF60A5FA = Color(0xFF60A5FA);
  static const Color cFF64748B = Color(0xFF64748B);
  static const Color cFF7A5CFF = Color(0xFF7A5CFF);
  static const Color cFF8B5CF6 = Color(0xFF8B5CF6);
  static const Color cFF94A3B8 = Color(0xFF94A3B8);
  static const Color cFFD1FAE5 = Color(0xFFD1FAE5);
  static const Color cFFD97706 = Color(0xFFD97706);
  static const Color cFFDBEAFE = Color(0xFFDBEAFE);
  static const Color cFFDC2626 = Color(0xFFDC2626);
  static const Color cFFDCFCE7 = Color(0xFFDCFCE7);
  static const Color cFFE2E8F0 = Color(0xFFE2E8F0);
  static const Color cFFE67E22 = Color(0xFFE67E22);
  static const Color cFFE74C3C = Color(0xFFE74C3C);
  static const Color cFFECFDF5 = Color(0xFFECFDF5);
  static const Color cFFF1C40F = Color(0xFFF1C40F);
  static const Color cFFF1F5F9 = Color(0xFFF1F5F9);
  static const Color cFFF59E0B = Color(0xFFF59E0B);
  static const Color cFFF5F7FA = Color(0xFFF5F7FA);
  static const Color cFFF8FAFC = Color(0xFFF8FAFC);
  static const Color cFFFACC15 = Color(0xFFFACC15);
  static const Color cFFFBBF24 = Color(0xFFFBBF24);
  static const Color cFFFBFDFF = Color(0xFFFBFDFF);
  static const Color cFFFD3A84 = Color(0xFFFD3A84);
  static const Color cFFFF5A5F = Color(0xFFFF5A5F);
  static const Color cFFFFFBEB = Color(0xFFFFFBEB);
  static const Color cFFFFFFFF = Color(0xFFFFFFFF);
}
