// Import the necessary packages
// Import the necessary packages
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // ⭐️ 1. IMPORT PROVIDER
import 'package:firebase_core/firebase_core.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart'; // ⭐️ 2. IMPORT YOUR NEW PROVIDER
import 'firebase_options.dart';
import 'package:sundayschool_app/login_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // --- UPDATED DURATION ---
  // Hold native splash for 1.6 seconds (1600 milliseconds)
  await Future.delayed(const Duration(milliseconds: 1600));
  FlutterNativeSplash.remove();

  // ⭐️ 3. WRAP YOUR APP WITH THE PROVIDER
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserDataProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sunday School Events',
      home: LoginScreen(),
    );
  }
}
