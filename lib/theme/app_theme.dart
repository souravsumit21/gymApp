import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette — Standard Light
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF7F7F8);
  static const Color primary = Color(0xFF111111);      // Black primary CTA
  static const Color primaryDim = Color(0xFF3A3A3A);
  static const Color accent = Color(0xFFFF6D00);       // Brand orange — highlights, streaks, alerts
  static const Color accentYellow = Color(0xFFEAB308); // Yellow for info/secondary accents
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textMuted = Color(0xFF9AA0A6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color cardBg = Color(0xFFFFFFFF);

  /// Compact type scale (~12.5% reduction) for display/headline/stat sizes.
  static const double fontScale = 0.875;

  static double sz(double base) => (base * fontScale).roundToDouble();

  /// Fixed body/UI sizes — not affected by [fontScale].
  static const double textBody = 14;
  static const double textLabel = 12;
  static const double textCaption = 11;
  static const double textIcon = 20;

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        background: background,
        surface: surface,
        primary: primary,
        secondary: accent,
        error: accent,
        onBackground: textPrimary,
        onSurface: textPrimary,
        onPrimary: background,
      ),
      textTheme: TextTheme(
        displayLarge: _lexend(
          fontSize: sz(52),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.05,
        ),
        displayMedium: _lexend(
          fontSize: sz(48),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.05,
        ),
        displaySmall: _lexend(
          fontSize: sz(40),
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
        headlineLarge: _lexend(
          fontSize: sz(32),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.05,
        ),
        headlineMedium: _lexend(
          fontSize: sz(22),
          fontWeight: FontWeight.w700,
          height: 1.05,
        ),
        headlineSmall: _lexend(
          fontSize: sz(22),
          fontWeight: FontWeight.w700,
          height: 1.05,
        ),
        bodyLarge: _lexend(
          fontSize: textBody,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
          height: 1.65,
        ),
        bodyMedium: _lexend(
          fontSize: textBody,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.2,
          height: 1.65,
        ),
        bodySmall: _lexend(
          fontSize: textCaption,
          fontWeight: FontWeight.w400,
          color: textMuted,
          letterSpacing: 0.2,
          height: 1.65,
        ),
        labelLarge: _lexend(
          fontSize: textLabel,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _lexend(
            fontSize: textBody,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            height: 1.05,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _lexend(
            fontSize: textBody,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            height: 1.05,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: _lexend(
          color: textMuted,
          fontSize: textBody,
          letterSpacing: 0.2,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        elevation: 0,
        selectedLabelStyle: _lexend(
          fontSize: textLabel,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        unselectedLabelStyle: _lexend(
          fontSize: textLabel,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: _lexend(
          fontSize: sz(32),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.05,
        ),
      ),
    );
  }

  static TextStyle _lexend({
    double? fontSize,
    FontWeight? fontWeight,
    Color color = textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.lexend(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

/// Lexend type-scale helpers for stats and labels outside [TextTheme].
class AppTypography {
  AppTypography._();

  static TextStyle statHero({Color color = AppTheme.textPrimary}) =>
      AppTheme._lexend(
        fontSize: AppTheme.sz(56),
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.0,
      );

  static TextStyle stat({
    Color color = AppTheme.textPrimary,
    double? fontSize,
  }) =>
      AppTheme._lexend(
        fontSize: fontSize ?? AppTheme.sz(40),
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.0,
      );

  static TextStyle statLabel({Color color = AppTheme.textMuted}) =>
      AppTheme._lexend(
        fontSize: AppTheme.textCaption,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 1.5,
        height: 1.65,
      );
}

// Custom gradient definitions
class AppGradients {
  static const LinearGradient primaryGlow = LinearGradient(
    colors: [Color(0xFF111111), Color(0xFF3A3A3A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSurface = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGlow = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F7F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
