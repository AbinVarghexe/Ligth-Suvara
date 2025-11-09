// Import the necessary packages
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // ⭐️ 1. IMPORT PROVIDER
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart'; // ⭐️ 2. IMPORT YOUR NEW PROVIDER
import 'firebase_options.dart';
import 'package:sundayschool_app/animated_splash_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ⭐️ 3. WRAP YOUR APP WITH THE PROVIDER
  runApp(
    ChangeNotifierProvider(
      create: (BuildContext context) => UserDataProvider(),
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sunday School Events',
      home: AnimatedSplashScreen(),
    );
  }
}
