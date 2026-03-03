import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/login_screen.dart';
import 'package:sundayschool_app/admin_dashboard_screen.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart';
import 'package:sundayschool_app/animator/animator_dashboard_screen.dart';
import 'package:sundayschool_app/parish/parish_dashboard_screen.dart'; // Added import
import 'package:sundayschool_app/admin/observer_remarks_login.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart'; // Import modern loader

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the provider
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    // 1. If loading, show modern spinner
    if (userDataProvider.isLoading) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: const Color(0xFF0D47A1), // Use app theme blue
            size: 50,
          ),
        ),
      );
    }

    // 2. If no user is logged in, show Login
    if (user == null) {
      return const LoginScreen();
    }

    // 3. If user is logged in, check role
    if (userDataProvider.userData.isAdmin) {
      return const AdminDashboardScreen();
    } else if (userDataProvider.userData.isParish) {
      return const ParishDashboardScreen();
    } else if (userDataProvider.userData.isSchool) {
      // Route school users to the main home screen; they can open Program Registration from there.
      return const HomeScreen();
    } else if (userDataProvider.userData.isAnimator) {
      return const AnimatorDashboardScreen();
    } else if (userDataProvider.userData.isObserver) {
      return const ObserverRemarksLoginScreen();
    } else if (userDataProvider.userData.isTeacher) {
      return const HomeScreen();
    } else {
      return const HomeScreen();
    }
  }
}
