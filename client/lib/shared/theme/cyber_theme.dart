import 'package:flutter/material.dart';

/// Dribbble AI SaaS Standard Theme for Project Kerberos.
class CyberTheme {
  // Ultra-Deep Obsidian Backgrounds
  static const Color background = Color(0xFF030712);
  static const Color surface = Color(0xFF0B0F19);
  static const Color surfaceElevated = Color(0xFF111827);
  static const Color surfaceGlass = Color(0xDD0B0F19); // 87% opacity for rich blur overlay

  // Precision Glass Borders
  static const Color border = Color(0x1FFFFFFF); // 12% white for ultra-fine luxury borders
  static const Color borderBright = Color(0x33FFFFFF); // 20% white on hover / focus
  static const Color borderCyan = Color(0x6606B6D4);
  static const Color borderEmerald = Color(0x6610B981);

  // Vibrant Telemetry & Aurora Accents
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanLight = Color(0xFF38BDF8);
  static const Color cyanGlow = Color(0xFF38BDF8);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color emeraldGlow = Color(0xFF34D399);
  static const Color indigo = Color(0xFF6366F1);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color coral = Color(0xFFF43F5E);
  static const Color amber = Color(0xFFF59E0B);

  // High-Contrast Typography
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Iridescent Gradients (Dribbble SaaS Signature)
  static const LinearGradient heroTextGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF1F5F9),
      Color(0xFFBAE6FD),
      Color(0xFFA7F3D0),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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

  static const LinearGradient auroraGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient glassSheenGradient = LinearGradient(
    colors: [
      Color(0x18FFFFFF),
      Color(0x05FFFFFF),
      Color(0x00FFFFFF),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
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
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 42,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0,
          height: 1.15,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 13,
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
          height: 1.5,
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
