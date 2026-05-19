import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:sundayschool_app/auth_wrapper.dart'; // Update import
import 'package:lottie/lottie.dart';
import 'package:sundayschool_app/main.dart'; // Import global future

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this);

    animationCompositionFuture.then((composition) {
      if (mounted) {
        _controller.duration = composition.duration;
        _controller.forward();
      }
    });

    // Use a listener for precise navigation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Navigate immediately when the animation is done
        if (mounted) {
          Navigator.of(context).pushReplacement(
            // Use a fade transition for a smoother visual hand-off
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AuthWrapper(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(
                milliseconds: 400,
              ), // Quick fade
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDecorativeOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1), // User-specified precise match
      body: Stack(
        children: [
          // ✨ Subtle Center Glow
          Center(
            child: _buildDecorativeOrb(400, const Color(0xFF1E4998).withOpacity(0.3)),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Perfectly centered
              children: [
                // Premium Entrance Animation: Fade + Scale + Blur
                FutureBuilder<LottieComposition>(
                  future: animationCompositionFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1500),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutExpo,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: (1 - value) * 15,
                                  sigmaY: (1 - value) * 15,
                                ),
                                child: child!,
                              ),
                            ),
                          );
                        },
                        child: Lottie(
                          composition: snapshot.data,
                          controller: _controller,
                          height: 320,
                          fit: BoxFit.contain,
                        ),
                      );
                    } else {
                      return const SizedBox(height: 320);
                    }
                  },
                ),
              ],
            ),
          ),

          // Branding Footer anchored at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Container(
                    height: 1,
                    width: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 1),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/images/doc.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
