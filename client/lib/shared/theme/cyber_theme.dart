import 'package:flutter/material.dart';

/// Luxury Obsidian Glassmorphism Design System for Project Kerberos.
class CyberTheme {
  // Deep Obsidian Backgrounds
  static const Color background = Color(0xFF080C14);
  static const Color surface = Color(0xFF0E1626);
  static const Color surfaceElevated = Color(0xFF141E33);
  static const Color surfaceGlass = Color(0xCC0E1626); // 80% opacity for blur overlay

  // Precision Borders
  static const Color border = Color(0xFF1E293B);
  static const Color borderBright = Color(0xFF334155);
  static const Color borderCyan = Color(0x5506B6D4);
  static const Color borderGreen = Color(0x5510B981);

  // Vibrant Telemetry Accents
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanGlow = Color(0xFF38BDF8);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldGlow = Color(0xFF34D399);
  static const Color indigo = Color(0xFF6366F1);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color coral = Color(0xFFF43F5E);
  static const Color amber = Color(0xFFF59E0B);

  // High-Contrast Typography
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x22FFFFFF),
      Color(0x05FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: cyan,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: emerald,
        surface: surface,
        error: coral,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
