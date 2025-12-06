import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/login_screen.dart';
import 'package:sundayschool_app/admin_dashboard_screen.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart';
import 'package:sundayschool_app/animator/animator_dashboard_screen.dart'; // Import the new screen

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the provider
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    // 1. If loading, show spinner
    if (userDataProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. If no user is logged in, show Login
    if (user == null) {
      return const LoginScreen();
    }

    // 3. If user is logged in, check role
    if (userDataProvider.userData.isAdmin) {
      return const AdminDashboardScreen();
    } else if (userDataProvider.userData.isAnimator) {
      return const AnimatorDashboardScreen();
    } else {
      return const HomeScreen();
    }
  }
}
