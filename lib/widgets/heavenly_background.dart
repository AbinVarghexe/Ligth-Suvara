import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ✨ HeavenlyBackground
/// A reusable premium background widget that provides:
/// - Animated glowing orbs (Peach, Blue, Gold)
/// - Floating particles and shooting stars
/// - Subtle glassmorphic gradients and scaling
class HeavenlyBackground extends StatefulWidget {
  final Widget child;
  final bool showImage;

  const HeavenlyBackground({
    super.key,
    required this.child,
    this.showImage = true,
  });

  @override
  State<HeavenlyBackground> createState() => _HeavenlyBackgroundState();
}

class _HeavenlyBackgroundState extends State<HeavenlyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedOrb({
    required Color color,
    required double size,
    required double left,
    required double top,
    required double dx,
    required double dy,
  }) {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Positioned(
          left: left + (dx * _bgAnimationController.value),
          top: top + (dy * _bgAnimationController.value),
          child: Opacity(
            opacity: 0.15 + (0.05 * _bgAnimationController.value),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color, color.withOpacity(0.0)],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✨ RepaintBoundary is critical for scrolling performance with complex backgrounds.
    // It prevents the background animations from forcing a repaint of the entire list, 
    // and vice-versa during scrolling.
    return RepaintBoundary(
      child: Stack(
        children: [
          // 1. Base Layer (Image or Gradient)
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.02 + (0.04 * _bgAnimationController.value),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    image: widget.showImage
                        ? const DecorationImage(
                            image: AssetImage('assets/images/login_bg.jpg'),
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high, // Prevents aliasing/banding
                          )
                        : null,
                    gradient: !widget.showImage
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.blue.shade50,
                              Colors.white,
                            ],
                          )
                        : null,
                  ),
                ),
              );
            },
          ),

          // 2. Animated Orbs
          _buildAnimatedOrb(
            color: const Color(0xFFFFDAB9), // Peach/Gold
            size: 400,
            left: -100,
            top: -100,
            dx: 40,
            dy: 30,
          ),
          _buildAnimatedOrb(
            color: const Color(0xFFB0E0E6), // Powder Blue
            size: 500,
            left: 200,
            top: 400,
            dx: -50,
            dy: -40,
          ),
          _buildAnimatedOrb(
            color: const Color(0xFFFFF8DC), // Cornsilk/Gold
            size: 300,
            left: -50,
            top: 600,
            dx: 30,
            dy: -20,
          ),

          // 3. Glass Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),

          // 4. Floating Particles
          const Positioned.fill(child: SharedFloatingParticles()),

          // 5. Content
          widget.child,
        ],
      ),
    );
  }
}

class SharedFloatingParticles extends StatefulWidget {
  const SharedFloatingParticles({super.key});

  @override
  State<SharedFloatingParticles> createState() => _SharedFloatingParticlesState();
}

class _SharedFloatingParticlesState extends State<SharedFloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<SharedParticle> _particles = List.generate(20, (_) => SharedParticle());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            painter: SharedParticlePainter(_particles, _controller.value),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class SharedParticle {
  late double x, y, size, speed;
  late double opacity;
  bool isShootingStar = false;
  static final math.Random _random = math.Random();

  SharedParticle() {
    reset();
  }

  void reset() {
    isShootingStar = _random.nextDouble() > 0.85;
    x = _random.nextDouble();
    y = _random.nextDouble();

    if (isShootingStar) {
      size = 1.0 + _random.nextDouble() * 1.5;
      speed = 0.5 + _random.nextDouble() * 1.0;
      opacity = 0.3 + _random.nextDouble() * 0.4;
    } else {
      size = 2 + _random.nextDouble() * 5;
      speed = 0.05 + _random.nextDouble() * 0.15;
      opacity = 0.05 + _random.nextDouble() * 0.15;
    }
  }
}

class SharedParticlePainter extends CustomPainter {
  final List<SharedParticle> particles;
  final double animationValue;

  SharedParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()..style = PaintingStyle.fill;

      if (p.isShootingStar) {
        final progress = (animationValue * p.speed) % 1.2;
        if (progress > 1.0) continue;

        final startX = p.x * size.width;
        final startY = p.y * size.height;
        final endX = startX + 120;
        final endY = startY + 80;

        final curX = startX + (endX - startX) * progress;
        final curY = startY + (endY - startY) * progress;

        final trailPaint = Paint()
          ..strokeWidth = p.size
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(0),
              Colors.white.withOpacity(p.opacity),
            ],
            begin: Alignment(
              startX / size.width * 2 - 1,
              startY / size.height * 2 - 1,
            ),
            end: Alignment(
              curX / size.width * 2 - 1,
              curY / size.height * 2 - 1,
            ),
          ).createShader(
            Rect.fromLTRB(
              math.min(startX, curX),
              math.min(startY, curY),
              math.max(startX, curX),
              math.max(startY, curY),
            ),
          )
          ..style = PaintingStyle.stroke;

        canvas.drawLine(Offset(startX, startY), Offset(curX, curY), trailPaint);
        paint.color = Colors.white.withOpacity(p.opacity);
        canvas.drawCircle(Offset(curX, curY), p.size, paint);
      } else {
        final x = (p.x * size.width + (animationValue * p.speed * size.width)) % size.width;
        final y = (p.y * size.height + math.sin(animationValue * 2 * math.pi + p.x) * 20) % size.height;

        paint.color = Colors.white.withOpacity(p.opacity);
        canvas.drawCircle(Offset(x, y), p.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SharedParticlePainter oldDelegate) => true;
}
