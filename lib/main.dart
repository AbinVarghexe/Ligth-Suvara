// Import the necessary packages
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart'; // ⭐️ 1. IMPORT PROVIDER
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart'; // ⭐️ 2. IMPORT YOUR NEW PROVIDER
import 'firebase_options.dart';
// Import the new AuthWrapper
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:sundayschool_app/animated_splash_screen.dart'; // Import the animated splash screen
import 'package:sundayschool_app/services/notification_service.dart'; // Import Notification Service
import 'package:lottie/lottie.dart';
import 'package:sundayschool_app/app_globals.dart'; // Global navigator key

import 'package:sundayschool_app/providers/content_provider.dart'; // Import ContentProvider

// Global future for preloaded animation
late Future<LottieComposition> animationCompositionFuture;

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Log synchronous and asynchronous Flutter errors to aid blank-screen debugging
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // Return true to consume the error and avoid app crash in release
    return false;
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
    );
  } catch (e) {
    debugPrint("App Check activation failed: $e");
  }

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Notification Service
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint("Notification Service init failed: $e");
  }

  // Preload Lottie Animation
  animationCompositionFuture = AssetLottie(
    'assets/images/animation n2.json',
  ).load();

  // ⭐️ 3. WRAP YOUR APP WITH THE PROVIDER
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserDataProvider()),
        ChangeNotifierProvider(
          create: (context) => ContentProvider(), // Added ContentProvider
        ),
      ],
      child: const MyApp(),
    ),
  );

  // Remove native splash after the first frame.
  widgetsBinding.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Sunday School Events',
      home: const AnimatedSplashScreen(), // Start with Animated Splash Screen
    );
  }
}
