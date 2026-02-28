// lib/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/admin_dashboard_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sundayschool_app/login_screen.dart';
import 'package:sundayschool_app/animator/animator_dashboard_screen.dart';
import 'package:sundayschool_app/parish/parish_dashboard_screen.dart';
import 'package:sundayschool_app/admin/observer_remarks_login.dart';

import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:sundayschool_app/services/notification_service.dart'; // Import NotificationService

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _exitController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Exit animation controller
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    // Exit animations
    _exitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeOut));

    _exitSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.3)).animate(
          CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
        );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _exitController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _animatedNavigate(Widget destination) async {
    // Start exit animation
    await _exitController.forward();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionDuration: Duration
              .zero, // No additional transition since we're animating in this screen
        ),
      );
    }
  }

  Future<void> _launchDialer(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the dialer.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to launch dialer: $e')));
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'Login Failed',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: <Widget>[
          TextButton(
            child: Text(
              'Okay',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logIn() async {
    // Hide keyboard when login is attempted
    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final user = userCredential.user;
      if (user != null) {
        // CORE FIX: Check for existing profile and create a placeholder if missing.
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          // Auto-create a minimal profile to eliminate the manual step.
          final schoolNameFromEmail = user.email!.split('@').first;
          await userDocRef.set({
            'email': user.email,
            'role': 'school', // Default role
            'schoolname':
                schoolNameFromEmail, // Default school name from email prefix
            'fullName': '', // Placeholder
            'phoneNumber': '', // Placeholder
            'profileImageUrl': null, // Placeholder
            'forane': '', // Initialize empty Forane
            'parish': '', // Initialize empty Parish
          }, SetOptions(merge: true));
        }

        // Fetch role directly from the doc we just got
        String? role;
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            role = data['role'];
          }
        }

        final isUserAdmin = role == 'admin';
        final isAnimator = role == 'animator';
        final isParish = role == 'parish';
        final isObserver = role == 'observer';

        if (mounted) {
          Widget destination;
          if (isUserAdmin) {
            destination = const AdminDashboardScreen();
          } else if (isParish) {
            destination = const ParishDashboardScreen();
          } else if (isAnimator) {
            destination = const AnimatorDashboardScreen();
          } else if (isObserver) {
            destination = const ObserverRemarksLoginScreen();
          } else {
            destination = const HomeScreen();
          }

          // --- Subscribe to all necessary topics ---

          if (!isParish) {
            // 1. Subscribe to user-specific topic (for individual messages)
            NotificationService().subscribeToUserTopic(user.uid);

            // 3. Subscribe to role-specific topic (e.g., 'role_school')
            if (role != null && role.isNotEmpty) {
              NotificationService().subscribeToRoleTopic(role);
            }
          } else {
            // 4. NEW: Subscribe Parish to linked school's topics
            if (userDoc.exists) {
              final data = userDoc.data();
              if (data != null) {
                final String? linkedSchoolId = data['schoolId']?.toString();
                if (linkedSchoolId != null && linkedSchoolId.isNotEmpty) {
                  NotificationService().subscribeToUserTopic(linkedSchoolId);
                  NotificationService().subscribeToRoleTopic('school');
                }
              }
            }
          }

          debugPrint(
            'Subscribed to topics: broadcasts, school_${user.uid}, role_$role',
          );

          await _animatedNavigate(destination);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Invalid credentials. Please try again.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'The email or password you entered is incorrect.';
      }

      if (mounted) {
        _showErrorDialog(message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentPadding = screenWidth > 600 ? screenWidth * 0.15 : 24.0;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.blue.shade900),
            onPressed: () async {
              if (Navigator.of(context).canPop()) {
                await _exitController.forward();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                await _animatedNavigate(const LoginScreen());
              }
            },
          ),
        ),
        // --- WRAPPED BODY IN A STACK ---
        body: Stack(
          children: [
            // Gradient Background Layer
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 1.0],
                  colors: [
                    Color(0xFFFFFAF0), // Very Soft Cream (Floral White)
                    Color(0xFFFFF8E1), // Ultra Light Gold
                  ],
                ),
              ),
            ),
            // --- MAIN CONTENT (ListView) ---
            FadeTransition(
              opacity:
                  _exitController.status == AnimationStatus.forward ||
                      _exitController.status == AnimationStatus.completed
                  ? _exitFadeAnimation
                  : _fadeAnimation,
              child: SlideTransition(
                position:
                    _exitController.status == AnimationStatus.forward ||
                        _exitController.status == AnimationStatus.completed
                    ? _exitSlideAnimation
                    : _slideAnimation,
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: contentPadding),
                  children: [
                    const SizedBox(height: 80), // Space for transparent AppBar
                    Text(
                      'Welcome',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28, // Slightly smaller font
                        fontWeight: FontWeight.bold,
                        color: const Color(
                          0xFF1E3A8A,
                        ), // Deep Blue from login_screen
                      ),
                    ),
                    const SizedBox(height: 20), // Reduced spacing
                    Text(
                      'Login name',
                      style: GoogleFonts.poppins(
                        fontSize: 16, // Slightly smaller font
                        color: const Color(
                          0xFF1E3A8A,
                        ), // Deep Blue from login_screen
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAuthField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      hintText: 'Enter your login name',
                      isPassword: false,
                    ),
                    const SizedBox(height: 16), // Reduced spacing
                    Text(
                      'Password',
                      style: GoogleFonts.poppins(
                        fontSize: 16, // Slightly smaller font
                        color: const Color(
                          0xFF1E3A8A,
                        ), // Deep Blue from login_screen
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAuthField(
                      controller: _passwordController,
                      hintText: 'Enter your password',
                      isPassword: true,
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        _launchDialer('+919447601251');
                      },
                      child: Text(
                        'Contact Admin',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.poppins(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // Reduced spacing
                    ElevatedButton(
                      onPressed: _isLoading ? null : _logIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ), // Reduced padding
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Log In',
                              style: GoogleFonts.poppins(
                                fontSize: 16, // Slightly smaller font
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 120), // Reduced spacing
                    FadeTransition(
                      opacity:
                          _exitController.status == AnimationStatus.forward ||
                              _exitController.status ==
                                  AnimationStatus.completed
                          ? _exitFadeAnimation
                          : _logoFadeAnimation,
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/suvara logo wbg6.png',
                            height: 70, // Reduced height
                            fit: BoxFit.contain,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 25.0, // Reduced padding
                            ),
                          ),
                          // Add padding at the bottom to ensure watermark doesn't overlap logos
                          const SizedBox(height: 40), // Space for the footer
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- WATERMARK ADDED BACK USING Positioned ---
            Positioned(
              bottom: 10, // Adjust the position from the bottom
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity:
                    _exitController.status == AnimationStatus.forward ||
                        _exitController.status == AnimationStatus.completed
                    ? _exitFadeAnimation
                    : _logoFadeAnimation,
                child: Text(
                  '© ${DateTime.now().year} AJCE. All Rights Reserved.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.blue.shade900.withAlpha(
                      128,
                    ), // Semi-transparent color
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthField({
    required TextEditingController controller,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    required bool isPassword,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50, // Light blue background
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.1), // Blue shadow
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword && !_passwordVisible,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18.0,
            horizontal: 20.0,
          ),
          border: InputBorder.none,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}
