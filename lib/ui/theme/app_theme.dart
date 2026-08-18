/// App theme — Kerala-inspired deep indigo/saffron/gold palette.
/// Dark mode first. Uses Noto Serif Malayalam + Inter fonts.
library app_theme;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Color palette
  // ---------------------------------------------------------------------------

  // Primary: Deep Kerala indigo (inspired by traditional Kerala temple walls)
  static const Color primaryDark = Color(0xFF1A1040);   // Deep indigo-violet
  static const Color primaryMid = Color(0xFF2D1B6B);    // Rich purple
  static const Color primarySurface = Color(0xFF231552); // Card background

  // Accent: Saffron/gold (inspired by lamp flame, festival)
  static const Color accentSaffron = Color(0xFFFF9F1C); // Saffron
  static const Color accentGold = Color(0xFFFFCC44);    // Gold
  static const Color accentGoldLight = Color(0xFFFFE082);// Pale gold

  // Text
  static const Color textPrimary = Color(0xFFF5F0E8);   // Warm white
  static const Color textSecondary = Color(0xFFBDB5D8);  // Muted lavender
  static const Color textMuted = Color(0xFF7A6E99);      // Dimmed

  // Status / flag colors
  static const Color spanColor = Color(0xFF4FC3F7);     // Sky blue — spanning
  static const Color skipColor = Color(0xFFFF8A65);     // Coral — skipped
  static const Color repeatColor = Color(0xFFA5D6A7);   // Sage green — repeat

  // Today highlight
  static const Color todayRing = Color(0xFFFF9F1C);     // Saffron ring

  // Surface variants
  static const Color surfaceCard = Color(0xFF2A1E6B);
  static const Color surfaceCardDim = Color(0xFF1E1550);
  static const Color surfaceDivider = Color(0xFF3D2E8A);

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static TextTheme get _textTheme => TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: 57, fontWeight: FontWeight.w300, color: textPrimary,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: 45, fontWeight: FontWeight.w300, color: textPrimary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 32, fontWeight: FontWeight.w600, color: textPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10, fontWeight: FontWeight.w500, color: textMuted,
    ),
  );

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: accentSaffron,
      onPrimary: primaryDark,
      secondary: accentGold,
      onSecondary: primaryDark,
      surface: primarySurface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceCard,
      outline: surfaceDivider,
      error: Color(0xFFFF6B6B),
    ),
    scaffoldBackgroundColor: primaryDark,
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    cardTheme: CardTheme(
      color: surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: surfaceDivider, width: 0.5),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(textPrimary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accentSaffron,
        foregroundColor: primaryDark,
        textStyle: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: surfaceDivider,
      thickness: 0.5,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textPrimary,
      iconColor: textSecondary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceCard,
      hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: surfaceDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: surfaceDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentSaffron, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: primarySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  // ---------------------------------------------------------------------------
  // Glassmorphism card decoration
  // ---------------------------------------------------------------------------

  static BoxDecoration glassCardDecoration({double opacity = 0.15}) =>
      BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      );

  // ---------------------------------------------------------------------------
  // Gradient backgrounds
  // ---------------------------------------------------------------------------

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1040), Color(0xFF0D0825), Color(0xFF1A0E3B)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D1B6B), Color(0xFF1A1040)],
  );

  static const LinearGradient saffronGradient = LinearGradient(
    colors: [Color(0xFFFF9F1C), Color(0xFFFFCC44)],
  );
}
