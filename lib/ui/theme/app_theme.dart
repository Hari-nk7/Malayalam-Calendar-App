/// App theme — Clean, subtle, modern production-grade theme.
/// Supports both Light and Dark modes with high legibility, refined typography (Inter),
/// and tasteful warm amber/terracotta accents.
library app_theme;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Color palette constants
  // ---------------------------------------------------------------------------

  // Accent: Refined warm amber / gold (traditional yet modern)
  static const Color accentAmber = Color(0xFFD97706); // Amber 600 (Light)
  static const Color accentAmberDark = Color(0xFFF59E0B); // Amber 500 (Dark)
  static const Color accentGold = Color(0xFFB45309); // Amber 700

  // Status / flag colors
  static const Color spanColorLight = Color(0xFF0284C7); // Sky 600
  static const Color spanColorDark = Color(0xFF38BDF8); // Sky 400
  static const Color skipColorLight = Color(0xFFE11D48); // Rose 600
  static const Color skipColorDark = Color(0xFFFB7185); // Rose 400
  static const Color repeatColorLight = Color(0xFF059669); // Emerald 600
  static const Color repeatColorDark = Color(0xFF34D399); // Emerald 400

  // Backward compatibility aliases
  static const Color accentSaffron = Color(0xFFD97706);
  static const Color accentGoldLight = Color(0xFFFDE68A);
  static const Color spanColor = Color(0xFF0284C7);
  static const Color skipColor = Color(0xFFE11D48);
  static const Color repeatColor = Color(0xFF059669);
  static const Color todayRing = Color(0xFFD97706);

  // ---------------------------------------------------------------------------
  // Light Mode Colors
  // ---------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFF8F9FA); // Porcelain off-white
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure white card
  static const Color lightSurfaceSubtle = Color(0xFFF1F3F5); // Subdued background
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200 border
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400

  // ---------------------------------------------------------------------------
  // Dark Mode Colors
  // ---------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF111215); // Matte obsidian
  static const Color darkSurface = Color(0xFF181A1F); // Dark graphite card
  static const Color darkSurfaceSubtle = Color(0xFF141519); // Subdued dark surface
  static const Color darkBorder = Color(0xFF262933); // Hairline divider
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500

  // Backward-compat aliases
  static const Color primaryDark = Color(0xFF111215);
  static const Color primaryMid = Color(0xFF181A1F);
  static const Color primarySurface = Color(0xFF181A1F);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color surfaceCard = Color(0xFF181A1F);
  static const Color surfaceCardDim = Color(0xFF141519);
  static const Color surfaceDivider = Color(0xFF262933);

  // ---------------------------------------------------------------------------
  // Typography generator
  // ---------------------------------------------------------------------------

  static TextTheme _buildTextTheme(Color primary, Color secondary, Color muted) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 57, fontWeight: FontWeight.w300, color: primary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 45, fontWeight: FontWeight.w300, color: primary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.4,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w600, color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w500, color: primary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, color: secondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400, color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, color: primary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400, color: secondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: primary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500, color: secondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w500, color: muted,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Light ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: accentAmber,
      onPrimary: Colors.white,
      secondary: accentGold,
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightSurfaceSubtle,
      outline: lightBorder,
      error: Color(0xFFDC2626),
    ),
    scaffoldBackgroundColor: lightBackground,
    textTheme: _buildTextTheme(lightTextPrimary, lightTextSecondary, lightTextMuted),
    appBarTheme: AppBarTheme(
      backgroundColor: lightBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: lightTextPrimary),
    ),
    cardTheme: CardTheme(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: lightBorder, width: 1.0),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorder,
      thickness: 1.0,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(lightTextPrimary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accentAmber,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      hintStyle: GoogleFonts.inter(color: lightTextMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentAmber, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Dark ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: accentAmberDark,
      onPrimary: darkBackground,
      secondary: accentGold,
      onSecondary: Colors.white,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceSubtle,
      outline: darkBorder,
      error: Color(0xFFEF4444),
    ),
    scaffoldBackgroundColor: darkBackground,
    textTheme: _buildTextTheme(darkTextPrimary, darkTextSecondary, darkTextMuted),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: darkTextPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: darkTextPrimary),
    ),
    cardTheme: CardTheme(
      color: darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: darkBorder, width: 1.0),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorder,
      thickness: 1.0,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(darkTextPrimary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accentAmberDark,
        foregroundColor: darkBackground,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      hintStyle: GoogleFonts.inter(color: darkTextMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentAmberDark, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );

  // Background decoration fallback
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBackground, darkBackground],
  );
}
