// lib/auth_screen.dart
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/admin_dashboard_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sundayschool_app/login_screen.dart';
import 'package:sundayschool_app/animator/animator_dashboard_screen.dart';
import 'package:sundayschool_app/parish/parish_dashboard_screen.dart';
import 'package:sundayschool_app/admin/observer_remarks_login.dart';
import 'package:sundayschool_app/credits_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:sundayschool_app/services/notification_service.dart'; // Import NotificationService
import 'package:sundayschool_app/services/log_service.dart'; // Import LogService
import 'package:provider/provider.dart';
import 'package:sundayschool_app/providers/content_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late AnimationController _exitController;
  late AnimationController _effectController; // For pulses/shimmer/blobs
  late AnimationController
  _breathingController; // For logo/input breathing glow

  int _remainingLockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();

    _exitController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _effectController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Listeners for focus changes to trigger UI rebuilds for interactive scaling
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));

    _checkLockoutStatus();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? true;
      if (_rememberMe) {
        _emailController.text = prefs.getString('saved_email') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
      }
    });
  }

  Future<void> _checkLockoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTimeMs = prefs.getInt('login_lockout_time') ?? 0;
    if (lockoutTimeMs > 0) {
      final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = currentTimeMs - lockoutTimeMs;
      const lockoutDurationMs = 600000; // 10 minutes

      if (elapsedMs < lockoutDurationMs) {
        final remainingMs = lockoutDurationMs - elapsedMs;
        setState(() {
          _remainingLockoutSeconds = (remainingMs / 1000).ceil();
        });
        _startLockoutTimer();
      } else {
        // Expired
        await prefs.remove('login_lockout_time');
        await prefs.setInt('login_failed_attempts', 0);
        setState(() {
          _remainingLockoutSeconds = 0;
        });
      }
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingLockoutSeconds <= 1) {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('login_lockout_time');
        await prefs.setInt('login_failed_attempts', 0);
        setState(() {
          _remainingLockoutSeconds = 0;
        });
      } else {
        setState(() {
          _remainingLockoutSeconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _exitController.dispose();
    _effectController.dispose();
    _breathingController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.2), // Lighter barrier
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.elasticOut.transform(anim1.value);
        return Transform.scale(
          scale: 0.8 + (0.2 * curve), // Spring scale 0.8 -> 1.0
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.25,
                      ), // Brighter glass
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.1),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFD4AF37),
                          size: 45,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Login Failed',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(
                              0xFF1E3A8A,
                            ).withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF1E3A8A,
                              ).withValues(alpha: 0.85),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Got it',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logIn() async {
    // Hide keyboard when login is attempted
    FocusScope.of(context).unfocus();

    if (!mounted) return;

    if (_remainingLockoutSeconds > 0) {
      final remainingMinutes = (_remainingLockoutSeconds / 60).ceil();
      _showErrorDialog(
        'Too many failed attempts. Please try again in $remainingMinutes minutes.',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lockoutTimeMs = prefs.getInt('login_lockout_time') ?? 0;
    final currentTimeMs = DateTime.now().millisecondsSinceEpoch;

    // 10 minutes cooling period = 600,000 milliseconds
    const lockoutDurationMs = 600000;

    if (lockoutTimeMs > 0) {
      final elapsedMs = currentTimeMs - lockoutTimeMs;
      if (elapsedMs < lockoutDurationMs) {
        final remainingMs = lockoutDurationMs - elapsedMs;
        setState(() {
          _remainingLockoutSeconds = (remainingMs / 1000).ceil();
        });
        _startLockoutTimer();
        final remainingMinutes = (remainingMs / 60000).ceil();
        if (mounted) {
          _showErrorDialog(
            'Too many failed attempts. Please try again in $remainingMinutes minutes.',
          );
        }
        return;
      } else {
        // Lockout expired, reset it
        await prefs.remove('login_lockout_time');
        await prefs.setInt('login_failed_attempts', 0);
        setState(() {
          _remainingLockoutSeconds = 0;
        });
      }
    }

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
        // Save or clear credentials based on rememberMe checkbox
        await prefs.setBool('remember_me', _rememberMe);
        if (_rememberMe) {
          await prefs.setString('saved_email', _emailController.text.trim());
          await prefs.setString('saved_password', _passwordController.text.trim());
        } else {
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }

        // Login succeeded, clear failed attempts
        await prefs.setInt('login_failed_attempts', 0);
        await prefs.remove('login_lockout_time');
        setState(() {
          _remainingLockoutSeconds = 0;
        });
        _lockoutTimer?.cancel();

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

        // Log the login action and initialize presence using RTDB
        try {
          final logService = LogService();
          await logService.logAction(
            'Login',
            'User logged in via mobile app',
            type: 'auth',
          );

          // Start tracking online status
          logService.initPresence(
            user.uid,
            user.email ?? 'Unknown',
            role ?? 'user',
          );
        } catch (e) {
          debugPrint('Error logging user access: $e');
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
          NotificationService().subscribeToBroadcastsWithRetry();

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
    } catch (e) {
      String message = 'The email or password you entered is incorrect.';
      String errorCode = '';
      if (e is FirebaseAuthException) {
        errorCode = e.code;
        if (e.message != null) {
          if (e.code != 'wrong-password' &&
              e.code != 'user-not-found' &&
              e.code != 'invalid-credential') {
            message = e.message!;
          }
        }
      } else {
        message = e.toString();
      }

      // Count any failed attempt except network failure
      if (errorCode != 'network-request-failed') {
        int failedAttempts = prefs.getInt('login_failed_attempts') ?? 0;
        failedAttempts += 1;
        await prefs.setInt('login_failed_attempts', failedAttempts);

        if (failedAttempts >= 3) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          await prefs.setInt('login_lockout_time', nowMs);
          setState(() {
            _remainingLockoutSeconds = 600; // 10 minutes
          });
          _startLockoutTimer();
          message =
              'You have entered incorrect credentials 3 times. You are locked out for 10 minutes.';
        } else {
          final remainingAttempts = 3 - failedAttempts;
          message =
              'The email or password you entered is incorrect. You have $remainingAttempts attempts remaining before 10 min lockout.';
        }
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

  Widget _buildButtonLoader() {
    return AnimatedBuilder(
      animation: _effectController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final t = (_effectController.value + (index * 0.2)) % 1.0;
            final opacity = math.sin(t * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3 + (0.7 * opacity)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4 * opacity),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// ðŸŒ„ Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/login_bg.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          /// ðŸŒ« Blur Overlay (Brightened)
          Container(color: Colors.white.withValues(alpha: 0.25)),

          /// ðŸ«§ Background Animated Blobs (Heavenly Particles)
          AnimatedBuilder(
            animation: _effectController,
            builder: (context, child) {
              return Stack(
                children: [
                  _buildBokehBlob(
                    0.2,
                    0.3,
                    200,
                    0,
                    Colors.white.withValues(alpha: 0.12),
                  ),
                  _buildBokehBlob(
                    0.7,
                    0.1,
                    300,
                    1500,
                    const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  ),
                  _buildBokehBlob(
                    0.5,
                    0.8,
                    250,
                    3000,
                    const Color(
                      0xFF60A5FA,
                    ).withValues(alpha: 0.1), // Lighter Sapphire
                  ),
                ],
              );
            },
          ),

          /// ðŸ“œ Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      /// âœ¨ Crystalline Liquid Logo Pod
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          AnimatedBuilder(
                            animation: _effectController,
                            builder: (context, child) {
                              final float =
                                  math.sin(
                                    _effectController.value * 2 * math.pi,
                                  ) *
                                  8;

                              return Transform.translate(
                                offset: Offset(0, float),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    /// 2. Unified Glass Container (Footer Style)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10,
                                          sigmaY: 10,
                                        ),
                                        child: Container(
                                          width: 145,
                                          height: 95,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Stack(
                                            children: const [
                                              // Inner Glow/Highlight could go here if needed
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    /// 3. Actual Logo (Centered)
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.rectangle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFFFD700,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 60,
                                            spreadRadius: 10,
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 30,
                                            spreadRadius: -2,
                                          ),
                                        ],
                                      ),
                                      child: AnimatedBuilder(
                                        animation: _breathingController,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale:
                                                1.0 +
                                                (0.02 *
                                                    _breathingController.value),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // 🌟 Modern Soft Glow
                                                ImageFiltered(
                                                  imageFilter: ImageFilter.blur(
                                                    sigmaX: 15.0,
                                                    sigmaY: 15.0,
                                                  ),
                                                  child: Image.asset(
                                                    "assets/images/new_logo_light.png",
                                                    height: 90,
                                                    fit: BoxFit.contain,
                                                    color: const Color(
                                                      0xFFFFD700,
                                                    ).withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                // 🌟 Crisp Professional Logo
                                                Image.asset(
                                                  "assets/images/new_logo_light.png",
                                                  height: 85,
                                                  fit: BoxFit.contain,
                                                  filterQuality:
                                                      FilterQuality.high,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      /// ðŸªŸ Glass Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: AnimatedBuilder(
                              animation: _effectController,
                              builder: (context, child) {
                                // Floating effect
                                final float =
                                    math.sin(
                                      _effectController.value * 2 * math.pi,
                                    ) *
                                    5;

                                return Transform.translate(
                                  offset: Offset(0, float),
                                  child: CustomPaint(
                                    painter: _GlowBorderPainter(
                                      animationValue: _effectController.value,
                                      borderRadius: 30,
                                      thickness: 2.0,
                                      gradientColors: [
                                        const Color(
                                          0xFFD4AF37,
                                        ).withValues(alpha: 0.6),
                                        Colors.white.withValues(alpha: 0.8),
                                        const Color(
                                          0xFFD4AF37,
                                        ).withValues(alpha: 0.6),
                                      ],
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          // Pure light glow instead of dark blue
                                          BoxShadow(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            blurRadius: 40,
                                            spreadRadius: -2,
                                          ),
                                          // Soft ambient floor
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  /// Title
                                  Text(
                                    "Welcome Back",
                                    style: GoogleFonts.outfit(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E3A8A),
                                      letterSpacing: 0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 25),

                                  /// Username Field
                                  _buildTextField(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    icon: Icons.person_outline_rounded,
                                    hint: "Login Name",
                                    textInputAction: TextInputAction.next,
                                  ),

                                  const SizedBox(height: 18),

                                  /// Password Field
                                  _buildTextField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    icon: Icons.lock_outline_rounded,
                                    hint: "Password",
                                    isPassword: true,
                                    textInputAction: TextInputAction.done,
                                    onEditingComplete: _logIn,
                                  ),

                                  const SizedBox(height: 12),

                                  /// Remember Me & Contact Admin Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Remember Me checkbox and text
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              activeColor: const Color(0xFF1E3A8A),
                                              checkColor: Colors.white,
                                              side: BorderSide(
                                                color: const Color(0xFF1E3A8A).withOpacity(0.5),
                                                width: 1.5,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  _rememberMe = value ?? false;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _rememberMe = !_rememberMe;
                                              });
                                            },
                                            child: Text(
                                              "Remember Me",
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF1E3A8A),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Contact Admin button
                                      TextButton(
                                        onPressed: () {
                                          final contentProvider =
                                              Provider.of<ContentProvider>(
                                                context,
                                                listen: false,
                                              );
                                          final contactPhone =
                                              contentProvider
                                                      .loginConfig['contactPhone']
                                                  as String?;
                                          final phone =
                                              (contactPhone != null &&
                                                  contactPhone.trim().isNotEmpty)
                                              ? contactPhone.trim()
                                              : '+919447601251';
                                          _launchDialer(phone);
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          "Contact Admin",
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF1E3A8A),
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 25),

                                  /// ðŸš€ Login Button with Blue Snake Glow
                                  SizedBox(
                                    width: double.infinity,
                                    child: AnimatedBuilder(
                                      animation: _effectController,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: _GlowBorderPainter(
                                            animationValue:
                                                _effectController.value,
                                            borderRadius: 22,
                                            thickness: 2.5,
                                            gradientColors: [
                                              Colors.blue.shade300,
                                              Colors.white,
                                              Colors.blue.shade300,
                                            ],
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF2563EB),
                                                  Color(0xFF1E40AF),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF1E40AF,
                                                  ).withValues(alpha: 0.4),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed:
                                                  (_isLoading ||
                                                      _remainingLockoutSeconds >
                                                          0)
                                                  ? null
                                                  : _logIn,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 18,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (_isLoading)
                                                    _buildButtonLoader()
                                                  else if (_remainingLockoutSeconds >
                                                      0) ...[
                                                    Text(
                                                      "Locked: ${_remainingLockoutSeconds ~/ 60}:${(_remainingLockoutSeconds % 60).toString().padLeft(2, '0')}",
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    const Icon(
                                                      Icons.lock_clock_rounded,
                                                      color: Colors.white70,
                                                      size: 22,
                                                    ),
                                                  ] else ...[
                                                    Text(
                                                      "Log In",
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      /// Footer
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  "assets/images/suvara logo wbg6.png",
                                  height: 60,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      CustomPageRoute(
                                        child: const CreditsScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.people_outline_rounded,
                                          size: 14,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Credits',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E3A8A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 10,
                                          color: Color(0xFFBC8A3A),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  height: 1,
                                  width: 40,
                                  color: const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "© ${DateTime.now().year} AJCE. All Rights Reserved.",
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: const Color(0xFF1E3A8A).withValues(
                                      alpha: 0.6,
                                    ), // Darker for visibility
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// Back Button
          Positioned(
            top: 10,
            left: 10,
            child: SafeArea(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFF1E3A8A),
                        size: 20,
                      ),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          _exitController.forward();
                          Navigator.of(context).pop();
                        } else {
                          _animatedNavigate(const LoginScreen());
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onEditingComplete,
  }) {
    final isFocused = focusNode.hasFocus;

    return AnimatedScale(
      scale: isFocused ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // Ambient light glow for focused field
            if (isFocused)
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),

            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _effectController,
          builder: (context, child) {
            return CustomPaint(
              painter: _GlowBorderPainter(
                animationValue: _effectController.value,
                borderRadius: 20,
                thickness: isFocused ? 2.0 : 1.5,
                gradientColors: [
                  (isFocused
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                  Colors.white.withValues(alpha: 0.6),
                  (isFocused
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                ],
              ),
              child: Stack(
                children: [
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: isPassword && !_passwordVisible,
                    textInputAction: textInputAction,
                    onEditingComplete: onEditingComplete,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E3A8A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        icon,
                        color: isFocused
                            ? const Color(0xFFD4AF37)
                            : const Color(0xFFD4AF37).withValues(alpha: 0.7),
                        size: 22,
                      ),
                      suffixIcon: isPassword
                          ? IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(
                                  0xFF1E3A8A,
                                ).withValues(alpha: 0.4),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            )
                          : null,
                      hintText: hint,
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                        fontSize: 15,
                      ),
                      filled: true,
                      // Boosted clarity when focused
                      fillColor: Colors.white.withOpacity(
                        isFocused ? 0.35 : 0.18,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Colors.transparent, // Border moved to painter
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFFD4AF37),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  // Inner Glow Light Catch
                  Positioned(
                    top: 1,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0),

                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// ðŸ«§ Helper for bokeh background particles
  Widget _buildBokehBlob(
    double x,
    double y,
    double size,
    int offsetMs,
    Color color,
  ) {
    // Generate organic motion based on the effect controller
    final posOffset = (x + y + (offsetMs / 1000));
    final animVal = (_effectController.value + posOffset) % 1.0;

    // Slow sinusoidal drifting
    final dx = 40 * math.sin(animVal * 2 * math.pi);
    final dy = 20 * math.cos(animVal * 2 * math.pi);

    return Positioned(
      left: (MediaQuery.of(context).size.width * x) + dx,
      top: (MediaQuery.of(context).size.height * y) + dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

/// ðŸŽ¨ Final Optimized 'Snake' Glow Painter
class _GlowBorderPainter extends CustomPainter {
  final double animationValue;
  final double borderRadius;
  final List<Color> gradientColors;
  final double thickness;

  _GlowBorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.gradientColors,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Halo Glow
    final Color glowColor = _getGlowColor(animationValue);
    final haloPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * 3
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 2);
    canvas.drawRRect(rRect, haloPaint);

    // 2. Moving Shimmer 'Snake'
    final List<Color> sweepColors = [
      Colors.transparent,
      gradientColors.first.withValues(alpha: 0.2),
      gradientColors.first,
      Colors.white,
      gradientColors.first,
      Colors.transparent,
    ];

    final shimmerPaint = Paint()
      ..shader = SweepGradient(
        colors: sweepColors,
        stops: const [0.0, 0.4, 0.48, 0.5, 0.52, 1.0],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rRect, shimmerPaint);
  }

  Color _getGlowColor(double t) {
    return Color.lerp(
      gradientColors.first,
      Colors.white,
      (math.sin(t * 2 * math.pi) + 1) / 2,
    )!;
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) => true;
}
