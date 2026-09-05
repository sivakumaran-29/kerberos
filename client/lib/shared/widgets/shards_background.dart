import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';

/// Static 3D Prismatic Shards ("Wind Sculpture") Background.
/// Completely static (no running loops/tickers), highly saturated rich colors:
/// - Deep velvet midnight amethyst backdrop with radiant purple aura
/// - Faceted prismatic diamond shards with saturated electric violet & lilac gradients
/// - Saturated dual-pass chromatic aberration (neon cyan & ruby magenta edges)
class ShardsBackground extends StatefulWidget {
  final Widget? child;
  final int shardCount;

  const ShardsBackground({
    super.key,
    this.child,
    this.shardCount = 110,
  });

  @override
  State<ShardsBackground> createState() => _ShardsBackgroundState();
}

class _ShardsBackgroundState extends State<ShardsBackground> {
  final List<_StaticShard> _shards = [];

  @override
  void initState() {
    super.initState();
    _initStaticShards();
  }

  void _initStaticShards() {
    _shards.clear();
    final random = math.Random(88); // Deterministic aesthetic placement
    for (int i = 0; i < widget.shardCount; i++) {
      _shards.add(_StaticShard.random(random, i, widget.shardCount));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Deep Saturated Radial Amethyst Backdrop
        Positioned.fill(
          child: Container(
            color: CyberTheme.background,
          ),
        ),

        // 2. Rich Glowing Center Amethyst Aura
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 0.9,
                  colors: [
                    Color(0x447C3AED), // Rich electric violet glow
                    Color(0x224C1D95), // Deep amethyst haze
                    Color(0x081A0B2E), // Subtle dark purple
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 3. Static Prismatic Shard Sculpture Canvas
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _StaticShardsPainter(_shards),
            ),
          ),
        ),

        // 4. Optional Child Content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _StaticShard {
  final double normX;
  final double normY;
  final double depth; // 0.35 (distant) to 1.6 (foreground)
  final double size;
  final double rotation;
  final double tilt;
  final double chromaticOffset;
  final double opacity;
  final Color primaryColor;
  final Color secondaryColor;

  _StaticShard({
    required this.normX,
    required this.normY,
    required this.depth,
    required this.size,
    required this.rotation,
    required this.tilt,
    required this.chromaticOffset,
    required this.opacity,
    required this.primaryColor,
    required this.secondaryColor,
  });

  factory _StaticShard.random(math.Random random, int index, int total) {
    final t = index / total;
    // Form a majestic curving flow / stream across the screen
    final streamCenterY = 0.5 - 0.25 * math.sin(t * math.pi * 1.8);
    final spreadY = (random.nextDouble() - 0.5) * 0.7;
    final y = (streamCenterY + spreadY).clamp(0.05, 0.95);
    final x = (t + (random.nextDouble() - 0.5) * 0.15).clamp(0.02, 0.98);

    final depth = 0.4 + random.nextDouble() * 1.1; // 0.4 to 1.5
    final size = (14.0 + random.nextDouble() * 26.0) * depth;
    final rotation = random.nextDouble() * math.pi * 2;
    final tilt = 0.4 + random.nextDouble() * 0.6; // 3D facet tilt ratio
    final chromaticOffset = (2.0 + random.nextDouble() * 3.5) * depth;
    final opacity = (0.55 + random.nextDouble() * 0.4).clamp(0.4, 0.95);

    // Highly saturated jewel & crystal tones
    final palettePairs = [
      [const Color(0xFFC084FC), const Color(0xFF7C3AED)], // Orchid to deep violet
      [const Color(0xFFA855F7), const Color(0xFF9333EA)], // Electric purple
      [const Color(0xFFD8B4FE), const Color(0xFF6D28D9)], // Bright lavender to amethyst
      [const Color(0xFF818CF8), const Color(0xFF4F46E5)], // Indigo crystal
      [const Color(0xFFE879F9), const Color(0xFFA21CAF)], // Neon fuchsia
    ];
    final pair = palettePairs[random.nextInt(palettePairs.length)];

    return _StaticShard(
      normX: x,
      normY: y,
      depth: depth,
      size: size,
      rotation: rotation,
      tilt: tilt,
      chromaticOffset: chromaticOffset,
      opacity: opacity,
      primaryColor: pair[0],
      secondaryColor: pair[1],
    );
  }
}

class _StaticShardsPainter extends CustomPainter {
  final List<_StaticShard> shards;

  _StaticShardsPainter(this.shards);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Sort distant to close for realistic 3D occlusion
    final sorted = List<_StaticShard>.from(shards)
      ..sort((a, b) => a.depth.compareTo(b.depth));

    for (final shard in sorted) {
      _drawFacetedShard(canvas, shard, size);
    }
  }

  void _drawFacetedShard(Canvas canvas, _StaticShard shard, Size screenSize) {
    final cx = shard.normX * screenSize.width;
    final cy = shard.normY * screenSize.height;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(shard.rotation);

    final halfW = shard.size * 0.45;
    final halfH = shard.size * 0.85 * shard.tilt;
    final offset = shard.chromaticOffset;

    // --- PASS 1: Saturated Cyan Chromatic Leading Edge ---
    final cyanPaint = Paint()
      ..color = const Color(0xFF06B6D4).withValues(alpha: shard.opacity * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final cyanPath = Path()
      ..moveTo(0, -halfH)
      ..lineTo(-halfW - offset, 0)
      ..lineTo(0, halfH);
    canvas.drawPath(cyanPath, cyanPaint);

    // --- PASS 2: Saturated Ruby/Magenta Trailing Edge ---
    final rubyPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: shard.opacity * 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final rubyPath = Path()
      ..moveTo(0, -halfH)
      ..lineTo(halfW + offset, 0)
      ..lineTo(0, halfH);
    canvas.drawPath(rubyPath, rubyPaint);

    // --- PASS 3: Primary Facet 1 (Top-Left Light Catch) ---
    final facet1 = Path()
      ..moveTo(0, -halfH)
      ..lineTo(-halfW, 0)
      ..lineTo(0, halfH)
      ..close();

    final paint1 = Paint()
      ..shader = LinearGradient(
        colors: [
          shard.primaryColor.withValues(alpha: shard.opacity),
          shard.secondaryColor.withValues(alpha: shard.opacity * 0.8),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(-halfW, -halfH, halfW, halfH * 2))
      ..style = PaintingStyle.fill;
    canvas.drawPath(facet1, paint1);

    // --- PASS 4: Secondary Facet 2 (Top-Right Deep Reflection) ---
    final facet2 = Path()
      ..moveTo(0, -halfH)
      ..lineTo(halfW, 0)
      ..lineTo(0, halfH)
      ..close();

    final paint2 = Paint()
      ..shader = LinearGradient(
        colors: [
          shard.primaryColor.withValues(alpha: shard.opacity * 0.7),
          const Color(0xFF3B0764).withValues(alpha: shard.opacity * 0.9),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, -halfH, halfW, halfH * 2))
      ..style = PaintingStyle.fill;
    canvas.drawPath(facet2, paint2);

    // --- PASS 5: Razor-Sharp Crystal Edge Spine ---
    final spinePaint = Paint()
      ..color = Colors.white.withValues(alpha: shard.opacity * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, -halfH), Offset(0, halfH), spinePaint);

    // Outer crystalline border
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: shard.opacity * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final fullDiamond = Path()
      ..moveTo(0, -halfH)
      ..lineTo(halfW, 0)
      ..lineTo(0, halfH)
      ..lineTo(-halfW, 0)
      ..close();
    canvas.drawPath(fullDiamond, outlinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StaticShardsPainter oldDelegate) => false;
}
