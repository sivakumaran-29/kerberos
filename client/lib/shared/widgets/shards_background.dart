import 'package:flutter/material.dart';

/// Dark Plain Gradient Background with Application Theme Glow & Heavy Edge Vignette.
/// - Rich deep midnight obsidian canvas (#06030A)
/// - Saturated application theme ambient radial glow (#7C3AED / #8B5CF6) centered behind hero content
/// - Heavy vignette falloff on ALL edges (top, bottom, left, right, and corners)
class ShardsBackground extends StatelessWidget {
  final Widget? child;

  const ShardsBackground({
    super.key,
    this.child,
    int? shardCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Ultra-Dark Midnight Obsidian Base Canvas
        Positioned.fill(
          child: Container(
            color: const Color(0xFF06030A),
          ),
        ),

        // 2. Application Theme Ambient Radial Glow (Center-Stage Halo)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.15),
                  radius: 0.85,
                  colors: [
                    Color(0x388B5CF6), // Luminous theme electric violet
                    Color(0x227C3AED), // Amethyst ambient halo
                    Color(0x0E4C1D95), // Deep purple mist
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 3. Secondary Subtle Theme Glow (Lower Horizon)
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, 0.55),
                  radius: 0.9,
                  colors: [
                    Color(0x187C3AED),
                    Color(0x084C1D95),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 4. Heavy Screen-Edge Vignette: Multi-stop Radial Edge Falloff
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x55000000),
                    Color(0xCC040108),
                    Color(0xFA020005),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.32, 0.62, 0.82, 0.94, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 5. Heavy Edge Vignette: Top Screen Edge Shadow
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 190,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF5020105),
                    Color(0xB2020105),
                    Color(0x44020105),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 6. Heavy Edge Vignette: Bottom Screen Edge Shadow
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 210,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFC020105),
                    Color(0xD0020105),
                    Color(0x55020105),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 7. Heavy Edge Vignette: Left Screen Edge Shadow
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: 190,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF5020105),
                    Color(0xA6020105),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 8. Heavy Edge Vignette: Right Screen Edge Shadow
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 190,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Color(0xF5020105),
                    Color(0xA6020105),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Optional Child Content
        if (child != null) child!,
      ],
    );
  }
}
