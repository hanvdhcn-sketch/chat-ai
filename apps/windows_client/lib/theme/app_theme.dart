import 'package:flutter/material.dart';

/// Orbita Fluent / Windows 11 visual system — navy left rail, white chat, gray tools.
class AppTheme {
  static const brandName = 'Orbita';
  static const brandSubtitle = 'Your AI assistant on Windows';

  // Brand / structure
  static const Color navy = Color(0xFF0B1220);
  static const Color navyElevated = Color(0xFF121A2B);
  static const Color navySoft = Color(0xFF1A2438);
  static const Color ink = Color(0xFF0F172A);
  static const Color inkMuted = Color(0xFF64748B);
  static const Color mist = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSoft = Color(0xFFD1D5DB);

  // Accents (Fluent blue — avoid purple-default AI look)
  static const Color accent = Color(0xFF2563EB);
  static const Color accentDeep = Color(0xFF1D4ED8);
  static const Color accentSoft = Color(0xFFEFF6FF);
  static const Color userBubble = Color(0xFFDBEAFE);
  static const Color success = Color(0xFF16A34A);
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldDeep = Color(0xFFEA580C);

  static const double radiusLg = 16;
  static const double radiusMd = 12;
  static const double radiusSm = 10;
  static const double leftNavWidth = 268;
  static const double rightPanelWidth = 292;

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        secondary: accentDeep,
        surface: surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surface,
      fontFamily: 'Segoe UI',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
        fontFamily: 'Segoe UI',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ink,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: inkMuted.withValues(alpha: 0.85)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
    );
  }
}
