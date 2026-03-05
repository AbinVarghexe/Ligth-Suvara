import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1), // Your splash screen color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Your Lottie animation
            FutureBuilder<LottieComposition>(
              future: animationCompositionFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Lottie(
                    composition: snapshot.data,
                    controller: _controller,
                    height: 100, // Reduced size
                  );
                } else {
                  return const SizedBox(
                    height: 100,
                  ); // Placeholder while loading
                }
              },
            ),
            const Spacer(flex: 2),
            // The new image at the bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Image.asset(
                'assets/images/doc.png', // Your new image
                height: 50, // Adjust size as needed
              ),
            ),
          ],
        ),
      ),
    );
  }
}
