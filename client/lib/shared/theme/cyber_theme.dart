import 'package:flutter/material.dart';

/// Exact React Bits Theme for Project Kerberos.
/// Colors and Material derived directly from React Bits wind sculpture specs:
/// - background: #120F17
/// - shardColor: #896ABD
/// - accentColor: #A855F7
class CyberTheme {
  // Exact React Bits Palette
  static const Color background = Color(0xFF120F17); // Deep midnight purple-black
  static const Color shardColor = Color(0xFF896ABD); // Pearl lavender shard body
  static const Color accentColor = Color(0xFFA855F7); // Electric purple accent
  
  // Surface Glassmorphism (Tuned to #120F17)
  static const Color surface = Color(0xFF181423); // Elevated midnight glass
  static const Color surfaceElevated = Color(0xFF211B30); // Higher elevation surface
  static const Color surfaceGlass = Color(0xD8181423); // Translucent for blur overlay

  // Precision Glass Borders
  static const Color border = Color(0x1FFFFFFF); // 12% white luxury edge
  static const Color borderBright = Color(0x33FFFFFF); // 20% white on hover
  static const Color borderAccent = Color(0x55A855F7); // Subtle purple glow border
  static const Color borderShard = Color(0x55896ABD); // Lavender accent border
  static const Color borderEmerald = Color(0x5534D399); // Emerald border
  static const Color borderCyan = Color(0x5538BDF8); // Cyan border

  // Accent Aliases for Telemetry & Integrity
  static const Color cyan = Color(0xFF38BDF8); // Cyan chromatic edge
  static const Color cyanLight = Color(0xFF7DD3FC);
  static const Color cyanGlow = Color(0xFF38BDF8);
  static const Color emerald = Color(0xFF34D399); // Verified state
  static const Color emeraldLight = Color(0xFF6EE7B7);
  static const Color emeraldGlow = Color(0xFF34D399);
  static const Color coral = Color(0xFFF43F5E); // Chromatic aberration red/magenta
  static const Color indigo = Color(0xFFA855F7); // Purple highlight

  // High-Contrast Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB5A9C9);
  static const Color textMuted = Color(0xFF7D7292);

  // Gradients
  static const LinearGradient shardGradient = LinearGradient(
    colors: [Color(0xFF896ABD), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
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
      primaryColor: accentColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: shardColor,
        surface: surface,
        error: coral,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 44,
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
