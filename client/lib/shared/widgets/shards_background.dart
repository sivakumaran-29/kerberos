import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';

/// 3D Prismatic Shards ("Wind Sculpture") Background Engine.
/// Replicates the exact React Bits animation specs:
/// - backgroundColor: #120F17
/// - shardColor: #896ABD
/// - accentColor: #A855F7
/// - flow: 'stream'
/// - material: 'pearl'
/// - chromaticAberration: 0.0075 (Cyan / Red edge dispersion)
/// - interaction: 'repel'
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

class _ShardsBackgroundState extends State<ShardsBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ShardParticle> _shards = [];
  final math.Random _random = math.Random(42);
  Offset? _mousePosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _initShards();
  }

  void _initShards() {
    _shards.clear();
    for (int i = 0; i < widget.shardCount; i++) {
      _shards.add(_ShardParticle.random(_random));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        setState(() {
          _mousePosition = event.localPosition;
        });
      },
      onExit: (_) {
        setState(() {
          _mousePosition = null;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Deep Midnight Background (#120F17)
          const ColoredBox(color: CyberTheme.background),

          // 2. Animated 3D Shards Canvas
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ShardsPainter(
                  shards: _shards,
                  progress: _controller.value,
                  mousePos: _mousePosition,
                ),
                size: Size.infinite,
              );
            },
          ),

          // 3. Optional Overlay Content
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _ShardParticle {
  double x; // 0..1 normalized
  double y; // 0..1 normalized
  double z; // 0.2..1.8 depth
  double size;
  double speed;
  double angle;
  double spinSpeed;
  double rollAngle;
  double rollSpeed;
  double aspect; // stretch factor
  double opacity;
  double hueShift;

  _ShardParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.size,
    required this.speed,
    required this.angle,
    required this.spinSpeed,
    required this.rollAngle,
    required this.rollSpeed,
    required this.aspect,
    required this.opacity,
    required this.hueShift,
  });

  factory _ShardParticle.random(math.Random rand) {
    return _ShardParticle(
      x: rand.nextDouble() * 1.3 - 0.15,
      y: rand.nextDouble() * 1.3 - 0.15,
      z: 0.3 + rand.nextDouble() * 1.4, // depth
      size: 14 + rand.nextDouble() * 26,
      speed: 0.08 + rand.nextDouble() * 0.14,
      angle: rand.nextDouble() * math.pi * 2,
      spinSpeed: (rand.nextDouble() - 0.5) * 2.5,
      rollAngle: rand.nextDouble() * math.pi,
      rollSpeed: (rand.nextDouble() - 0.5) * 3.0,
      aspect: 0.8 + rand.nextDouble() * 0.8, // stretch
      opacity: 0.4 + rand.nextDouble() * 0.55,
      hueShift: rand.nextDouble(),
    );
  }

  void update(double dt, Size size, Offset? mousePos) {
    // Stream flow: diagonal curved sweep with natural turbulence
    final wave = math.sin(y * 4.0 + angle) * 0.04;
    x += (speed * 0.6 + wave) * dt;
    y += (speed * 0.45) * dt;

    // Spin and roll tumble
    angle += spinSpeed * dt;
    rollAngle += rollSpeed * dt;

    // Interactive cursor repulsion ('repel' mode from React Bits)
    if (mousePos != null && size.width > 0 && size.height > 0) {
      final screenX = x * size.width;
      final screenY = y * size.height;
      final dx = screenX - mousePos.dx;
      final dy = screenY - mousePos.dy;
      final distSq = dx * dx + dy * dy;
      const radius = 160.0;
      if (distSq < radius * radius && distSq > 1) {
        final dist = math.sqrt(distSq);
        final force = (1.0 - (dist / radius)) * 0.25;
        x += (dx / dist) * force * dt;
        y += (dy / dist) * force * dt;
      }
    }

    // Wrap around screen boundaries seamlessly
    if (x > 1.2) x = -0.2;
    if (x < -0.2) x = 1.2;
    if (y > 1.2) y = -0.2;
    if (y < -0.2) y = 1.2;
  }
}

class _ShardsPainter extends CustomPainter {
  final List<_ShardParticle> shards;
  final double progress;
  final Offset? mousePos;
  double _lastProgress = 0.0;

  _ShardsPainter({
    required this.shards,
    required this.progress,
    this.mousePos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Compute delta time
    double dt = progress - _lastProgress;
    if (dt < 0) dt += 1.0;
    if (dt > 0.1) dt = 0.016; // clamp
    _lastProgress = progress;

    // Sort by depth so far shards are drawn behind closer shards
    shards.sort((a, b) => a.z.compareTo(b.z));

    final paintBody = Paint()..style = PaintingStyle.fill;
    final paintChromaticCyan = Paint()..style = PaintingStyle.fill;
    final paintChromaticCoral = Paint()..style = PaintingStyle.fill;
    final paintEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final shard in shards) {
      shard.update(dt, size, mousePos);

      final centerX = shard.x * size.width;
      final centerY = shard.y * size.height;

      // 3D Perspective scaling (closer shards are larger)
      final depthScale = shard.z;
      final currentSize = shard.size * depthScale * 1.1;
      final currentWidth = currentSize * 0.55 * shard.aspect;
      final currentHeight = currentSize * 1.15;

      // Pearl surface colors (#896ABD and #A855F7)
      final pearlAlpha = (shard.opacity * math.min(1.0, depthScale * 0.8)).clamp(0.1, 1.0);
      final isAccent = shard.hueShift > 0.55;

      final baseColor = isAccent ? CyberTheme.accentColor : CyberTheme.shardColor;
      final highlightColor = isAccent ? const Color(0xFFC084FC) : const Color(0xFFB5A9C9);

      // 3D Polygon Vertices (Diamond / Rhombus Shard)
      final cosA = math.cos(shard.angle);
      final sinA = math.sin(shard.angle);
      final rollFactor = math.cos(shard.rollAngle).abs();

      // Transform local diamond vertices: top, right, bottom, left
      Offset rotate(double lx, double ly) {
        final rx = lx * rollFactor;
        final x = rx * cosA - ly * sinA;
        final y = rx * sinA + ly * cosA;
        return Offset(centerX + x, centerY + y);
      }

      final top = rotate(0, -currentHeight * 0.5);
      final right = rotate(currentWidth * 0.5, 0);
      final bottom = rotate(0, currentHeight * 0.5);
      final left = rotate(-currentWidth * 0.5, 0);

      final shardPath = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..lineTo(left.dx, left.dy)
        ..close();

      // ==========================================
      // CHROMATIC ABERRATION PASS (0.0075 offset)
      // Cyan on leading edge, Coral/Red on trailing edge
      // ==========================================
      final aberrationOffset = 2.4 * depthScale;

      // 1. Cyan offset pass
      final cyanPath = shardPath.shift(Offset(-aberrationOffset, -aberrationOffset * 0.5));
      paintChromaticCyan.color = CyberTheme.cyan.withValues(alpha: pearlAlpha * 0.38);
      canvas.drawPath(cyanPath, paintChromaticCyan);

      // 2. Coral/Red offset pass
      final coralPath = shardPath.shift(Offset(aberrationOffset, aberrationOffset * 0.5));
      paintChromaticCoral.color = CyberTheme.coral.withValues(alpha: pearlAlpha * 0.38);
      canvas.drawPath(coralPath, paintChromaticCoral);

      // ==========================================
      // MAIN PEARL MATERIAL PASS (#896ABD / #A855F7)
      // ==========================================
      paintBody.shader = LinearGradient(
        colors: [
          highlightColor.withValues(alpha: pearlAlpha * 0.95),
          baseColor.withValues(alpha: pearlAlpha * 0.85),
          const Color(0xFF4C3375).withValues(alpha: pearlAlpha * 0.7),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: Offset(centerX, centerY), width: currentWidth, height: currentHeight));

      canvas.drawPath(shardPath, paintBody);

      // Specular highlight stroke
      paintEdge.color = Colors.white.withValues(alpha: pearlAlpha * 0.35);
      canvas.drawPath(shardPath, paintEdge);
    }
  }

  @override
  bool shouldRepaint(covariant _ShardsPainter oldDelegate) => true;
}
