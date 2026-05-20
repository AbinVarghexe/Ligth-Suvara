// lib/homescreen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sundayschool_app/auth_screen.dart';
import 'package:sundayschool_app/uploadscreen.dart';
import 'package:sundayschool_app/notification_screen.dart';
import 'package:sundayschool_app/admin_dashboard_screen.dart';
import 'package:sundayschool_app/event_detail_screen.dart';
import 'package:sundayschool_app/profile_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:async/async.dart'; // Removed StreamZip dependency
import 'package:sundayschool_app/services/notification_service.dart';
import 'package:rxdart/rxdart.dart';

import 'package:sundayschool_app/animator/registration_dashboard.dart';
import 'package:sundayschool_app/animator/school_my_registrations_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum SortOption { newestFirst, alphabetical }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static Map<String, dynamic> getEventPlaceholderData(String category) {
    final cat = category.toUpperCase();
    if (cat == 'CML') {
      return {
        'icon': Icons.celebration_rounded,
        'color': const Color(0xFF5C35B3), // Deep violet
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C4DDB), Color(0xFF3D1A8E)], // Rich violet-indigo
        ),
      };
    } else if (cat == 'SUVARA') {
      return {
        'icon': Icons.star_rounded,
        'color': const Color(0xFFBF8A00), // Deep gold
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCA28), Color(0xFFE67E00)], // Golden amber
        ),
      };
    }
    return {
      'icon': Icons.event_rounded,
      'color': Color(0xFF1565C0),
      'gradient': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.blue.shade400, Colors.blue.shade800],
      ),
    };
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  SortOption _currentSortOption = SortOption.newestFirst;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isFabExpanded = false;

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabMenuController.forward();
      } else {
        _fabMenuController.reverse();
      }
    });
  }

  void _showRegistrationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registration Options',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistrationDashboard(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.app_registration_rounded,
                            size: 40,
                            color: Colors.blue.shade900,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'New\nRegistration',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SchoolMyRegistrationsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_turned_in_rounded,
                            size: 40,
                            color: Colors.green.shade800,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'My\nRegistrations',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['ALL', 'CML', 'SUVARA'];

  String _schoolDisplayName = 'Loading...';
  String? _profileImageUrl;
  bool _isAdmin = false;
  bool _isObserverMinimized = false;
  bool _isObserverCollapsed = false;

  late AnimationController _headerAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _fabMenuController; // New controller
  late Animation<double> _headerAnimation;
  late Animation<double> _fabAnimation;
  late Animation<double> _fabMenuAnimation; // New animation

  Stream<QuerySnapshot>? _eventsStream;

  void _setupEventsStream() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    Query baseQuery = FirebaseFirestore.instance
        .collection('events')
        .orderBy('timestamp', descending: true);

    if (!_isAdmin && currentUserUid != null) {
      baseQuery = baseQuery.where('creatorId', isEqualTo: currentUserUid);
    }
    _eventsStream = baseQuery.snapshots();
  }

  // --- NEW: Dynamic Notification Stream ---
  Stream<List<QuerySnapshot>>? _notificationStream;

  void _updateNotificationStream(String uid, String? role) {
    // 1. Determine which recipients to listen for
    final recipients = [uid]; // Always listen for own messages

    // 2. If user is a School Admin, listen for 'role_school' messages
    //    'all' is deprecated for notifications but kept for backward compatibility if needed.
    //    But strictly, we want to AVOID listening to 'all' if it was used globally.
    //    For now, we only add 'role_school' if the user has that role.
    if (role == 'school') {
      recipients.add('role_school');
    }

    // 3. Create the stream
    _notificationStream = Rx.combineLatest2(
      FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', whereIn: recipients)
          .snapshots(),
      FirebaseFirestore.instance.collection('broadcasts').snapshots(),
      (QuerySnapshot a, QuerySnapshot b) => [a, b],
    ).asBroadcastStream();
  }

  Stream<QuerySnapshot>? _activeProgramsStream;
  Stream<List<QuerySnapshot>>? _observerAssignmentsStream;

  void _setupObserverStream() {
    _observerAssignmentsStream = Rx.combineLatest2(
      FirebaseFirestore.instance
          .collection('assignments')
          .where('type', isEqualTo: 'Observer')
          .snapshots(),
      FirebaseFirestore.instance
          .collection('settings')
          .doc('observer_dates')
          .collection('years')
          .snapshots(),
      (QuerySnapshot assignments, QuerySnapshot settings) => [
        assignments,
        settings,
      ],
    ).shareValue();
  }

  void _setupActiveProgramsStream() {
    _activeProgramsStream = FirebaseFirestore.instance
        .collection('programs')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _setupEventsStream(); // Initial setup
    _setupActiveProgramsStream(); // Initial setup for banner
    _setupObserverStream(); // Setup observer stream out of build
    _loadUserData();
    _loadObserverPreference();
    _searchController.addListener(_onSearchChanged);

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    );
    _headerAnimationController.forward();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );

    // New Menu Animation
    _fabMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabMenuAnimation = CurvedAnimation(
      parent: _fabMenuController,
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fabAnimationController.forward();
    });
  }

  Future<void> _loadObserverPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isObserverMinimized =
            prefs.getBool('observer_minimized_school') ?? false;
        _isObserverCollapsed =
            prefs.getBool('observer_collapsed_school') ?? false;
      });
    }
  }

  Future<void> _saveObserverPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('observer_minimized_school', _isObserverMinimized);
    await prefs.setBool('observer_collapsed_school', _isObserverCollapsed);
  }

  Future<void> _toggleObserverMinimized() async {
    setState(() {
      _isObserverMinimized = !_isObserverMinimized;
      if (!_isObserverMinimized) {
        _isObserverCollapsed = false; // Auto-expand details when restored
      }
      _saveObserverPreference();
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _toggleObserverCollapsed() async {
    setState(() {
      _isObserverCollapsed = !_isObserverCollapsed;
      _saveObserverPreference();
    });
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _headerAnimationController.dispose();
    _fabAnimationController.dispose();
    _fabMenuController.dispose(); // Dispose new controller
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _schoolDisplayName = 'Guest User';
          _profileImageUrl = null;
          _isAdmin = false;
        });
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String finalDisplayName = user.email?.split('@').first ?? 'User';
      String? imageUrl;
      bool localIsAdmin = false;

      String? role;

      if (userDoc.exists) {
        final data = userDoc.data();
        final schoolName = data?['schoolName'] ?? data?['schoolname'];
        if (schoolName != null && schoolName.toString().isNotEmpty) {
          finalDisplayName = schoolName.toString();
        }
        imageUrl = data?['profileImageUrl']?.toString();
        localIsAdmin = data?['role'] == 'admin';
        role = data?['role']?.toString();
      }
      if (mounted) {
        setState(() {
          _schoolDisplayName = finalDisplayName;
          _profileImageUrl = imageUrl;
          _isAdmin = localIsAdmin;
          _setupEventsStream();

          //Start of Fix
          final schoolId = user.uid;

          // 1. Subscribe to personal school topic
          NotificationService().subscribeToUserTopic(schoolId);

          // 3. Subscribe to role topic (if any)
          if (role != null) {
            NotificationService().subscribeToRoleTopic(role);
          }

          // 3. Update Notification Stream Query
          _updateNotificationStream(user.uid, role);
        });
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (mounted) {
        setState(() => _schoolDisplayName = 'Error');
      }
    }
  }

  void _showSortDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Sort Events By',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption(
              'Newest First',
              Icons.schedule_rounded,
              SortOption.newestFirst,
            ),
            _buildSortOption(
              'Alphabetical (A-Z)',
              Icons.sort_by_alpha_rounded,
              SortOption.alphabetical,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, IconData icon, SortOption option) {
    final isSelected = _currentSortOption == option;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentSortOption = option);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade900 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Colors.blue.shade900
                      : Colors.grey.shade700,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade900, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.logout_rounded, color: Colors.red.shade600),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // --- CLEANUP: Unsubscribe from ALL topics before logging out ---
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // Fetch user role
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          String? role;
          String? schoolId;
          if (userDoc.exists) {
            role = userDoc.data()?['role']?.toString();
            schoolId = userDoc.data()?['schoolId']?.toString();
          }

          // Unsubscribe from user-specific topic first
          NotificationService().unsubscribeFromUserTopic(user.uid).catchError((
            e,
          ) {
            debugPrint('Error unsubscribing from user topic: $e');
          });

          // Unsubscribe from role topic if exists
          if (role != null && role.isNotEmpty) {
            NotificationService().unsubscribeFromRoleTopic(role).catchError((
              e,
            ) {
              debugPrint('Error unsubscribing from role topic: $e');
            });
          }

          // Unsubscribe from specific school topics if present
          if (schoolId != null && schoolId.isNotEmpty) {
            NotificationService().unsubscribeFromUserTopic(schoolId).catchError(
              (e) {
                debugPrint('Error unsubscribing from linked school topic: $e');
              },
            );
          }

          if (role == 'parish' || role == 'school') {
            NotificationService().unsubscribeFromRoleTopic('school').catchError(
              (e) {
                debugPrint('Error unsubscribing from school role topic: $e');
              },
            );
          }
        } catch (e) {
          debugPrint('Error getting user role for unsubscribe: $e');
        }
      }

      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildModernAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildActiveProgramsBanner(),
                    if (!_isObserverMinimized) ...[
                      _buildObserverSection(),
                      const SizedBox(height: 24),
                    ],
                    _buildHighlightSection(),
                    const SizedBox(height: 32),
                    _buildRecentEventsSection(),
                  ],
                ),
              ),
            ],
          ),
          if (_isObserverMinimized) _buildFloatingObserverButton(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            ScaleTransition(
              scale: _fabMenuAnimation,
              child: FloatingActionButton.extended(
                heroTag: 'fab_new_event',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _toggleFab();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UploadScreen(),
                    ),
                  );
                },
                backgroundColor: Colors.blue.shade900,
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  'New Event',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ScaleTransition(
              scale: _fabMenuAnimation,
              child: FloatingActionButton.extended(
                heroTag: 'fab_registration',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _toggleFab();
                  _showRegistrationOptions();
                },
                backgroundColor: Colors.orange.shade800,
                icon: const Icon(Icons.how_to_reg_rounded, color: Colors.white),
                label: Text(
                  'Registration',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ScaleTransition(
            scale: _fabAnimation,
            child: FloatingActionButton(
              heroTag: 'fab_main',
              onPressed: () {
                HapticFeedback.lightImpact();
                _toggleFab();
              },
              backgroundColor: _isFabExpanded
                  ? Colors.grey.shade800
                  : Colors.blue.shade900,
              child: Icon(
                _isFabExpanded ? Icons.close_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          SizedBox(height: (MediaQuery.paddingOf(context).bottom * 0.4) + 8),
        ],
      ),
    );
  }

  Widget _buildObserverSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<QuerySnapshot>>(
      stream: _observerAssignmentsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final assignmentsData = snapshot.data![0];
        final settingsData = snapshot.data![1];

        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);

        final Map<String, DateTime> expirationDates = {};
        for (var doc in settingsData.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['expirationDate'] != null) {
            expirationDates[doc.id] = (data['expirationDate'] as Timestamp)
                .toDate();
          }
        }

        bool isExpired(String? academicYear) {
          if (academicYear == null ||
              !expirationDates.containsKey(academicYear)) {
            return false;
          }
          return expirationDates[academicYear]!.isBefore(todayMidnight);
        }

        final incoming = assignmentsData.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['targetSchoolId'] != user.uid) return false;
          if (isExpired(data['academicYear'])) return false;
          return true;
        }).toList();

        final outgoing = assignmentsData.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['sourceSchoolId'] != user.uid) return false;
          if (isExpired(data['academicYear'])) return false;
          return true;
        }).toList();

        if (incoming.isEmpty && outgoing.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.indigo.shade400,
                                Colors.indigo.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.shade400.withAlpha(77),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.assignment_ind_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Observer Assignments',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _toggleObserverCollapsed,
                        icon: AnimatedRotation(
                          turns: _isObserverCollapsed ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey.shade400,
                            size: 24,
                          ),
                        ),
                        tooltip: _isObserverCollapsed ? 'Expand' : 'Collapse',
                      ),
                      IconButton(
                        onPressed: _toggleObserverMinimized,
                        icon: Icon(
                          Icons.close_fullscreen_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        tooltip: 'Minimize to floating button',
                      ),
                    ],
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (incoming.isNotEmpty)
                      _buildObserverCard(
                        title: 'Incoming Observer (at your school)',
                        observerName:
                            (incoming.first.data()
                                as Map<String, dynamic>)['teacherName'] ??
                            'Unknown',
                        schoolName:
                            (incoming.first.data()
                                as Map<String, dynamic>)['sourceSchoolName'] ??
                            'Unknown',
                        isIncoming: true,
                        phone:
                            (incoming.first.data()
                                as Map<String, dynamic>)['teacherPhone'],
                      ),
                    if (incoming.isNotEmpty && outgoing.isNotEmpty)
                      const SizedBox(height: 12),
                    if (outgoing.isNotEmpty)
                      ...outgoing.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildObserverCard(
                            title: 'Outgoing Observer (from your school)',
                            observerName: data['teacherName'] ?? 'Unknown',
                            schoolName: data['targetSchoolName'] ?? 'Unknown',
                            isIncoming: false,
                            phone: data['teacherPhone'],
                          ),
                        );
                      }),
                  ],
                ),
                crossFadeState: _isObserverCollapsed
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingObserverButton() {
    return Positioned(
      right: 20,
      bottom: 84 + (MediaQuery.paddingOf(context).bottom * 0.4),
      child: StreamBuilder<List<QuerySnapshot>>(
        stream: _observerAssignmentsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final assignmentsData = snapshot.data![0];
          final settingsData = snapshot.data![1];
          final user = FirebaseAuth.instance.currentUser;

          if (user == null || assignmentsData.docs.isEmpty) {
            return const SizedBox.shrink();
          }

          final now = DateTime.now();
          final todayMidnight = DateTime(now.year, now.month, now.day);

          final Map<String, DateTime> expirationDates = {};
          for (var doc in settingsData.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['expirationDate'] != null) {
              expirationDates[doc.id] = (data['expirationDate'] as Timestamp)
                  .toDate();
            }
          }

          bool isExpired(String? academicYear) {
            if (academicYear == null ||
                !expirationDates.containsKey(academicYear)) {
              return false;
            }
            return expirationDates[academicYear]!.isBefore(todayMidnight);
          }

          final incoming = assignmentsData.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['targetSchoolId'] == user.uid &&
                !isExpired(data['academicYear']);
          }).toList();

          final outgoing = assignmentsData.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['sourceSchoolId'] == user.uid &&
                !isExpired(data['academicYear']);
          }).toList();

          if (incoming.isEmpty && outgoing.isEmpty) {
            return const SizedBox.shrink();
          }

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _showObserverDetailsModal(incoming, outgoing);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade900.withValues(
                              alpha: 0.8,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_ind_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Observers',
                          style: GoogleFonts.poppins(
                            color: Colors.indigo.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showObserverDetailsModal(
    List<DocumentSnapshot> incoming,
    List<DocumentSnapshot> outgoing,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_ind_rounded,
                          color: Colors.indigo.shade900,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Observer Details',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _isObserverMinimized = false;
                              _isObserverCollapsed = false;
                              _saveObserverPreference();
                            });
                          },
                          icon: const Icon(
                            Icons.open_in_full_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Expand',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.indigo.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (incoming.isNotEmpty) ...[
                      _buildObserverCard(
                        title: 'Incoming Observer',
                        observerName:
                            (incoming.first.data()
                                as Map<String, dynamic>)['teacherName'] ??
                            'Unknown',
                        schoolName:
                            (incoming.first.data()
                                as Map<String, dynamic>)['sourceSchoolName'] ??
                            'Unknown',
                        isIncoming: true,
                        phone:
                            (incoming.first.data()
                                as Map<String, dynamic>)['teacherPhone'],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (outgoing.isNotEmpty)
                      ...outgoing.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildObserverCard(
                            title: 'Outgoing Observer',
                            observerName: data['teacherName'] ?? 'Unknown',
                            schoolName: data['targetSchoolName'] ?? 'Unknown',
                            isIncoming: false,
                            phone: data['teacherPhone'],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildObserverCard({
    required String title,
    required String observerName,
    required String schoolName,
    required bool isIncoming,
    String? phone,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showAssignmentDetails(
          title: title,
          observerName: observerName,
          schoolName: schoolName,
          isIncoming: isIncoming,
          phone: phone,
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isIncoming ? Colors.indigo.shade100 : Colors.orange.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isIncoming ? Colors.indigo.shade50 : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncoming ? Icons.login_rounded : Icons.logout_rounded,
                color:
                    isIncoming ? Colors.indigo.shade700 : Colors.orange.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    observerName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isIncoming ? 'From: $schoolName' : 'Going to: $schoolName',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (phone != null && phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              phone,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (phone != null && phone.isNotEmpty)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.call,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                ),
                onPressed: () async {
                  final url = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not launch dialer'),
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAssignmentDetails({
    required String title,
    required String observerName,
    required String schoolName,
    required bool isIncoming,
    String? phone,
  }) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.94),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isIncoming
                            ? [Colors.indigo.shade600, Colors.indigo.shade400]
                            : [Colors.orange.shade600, Colors.orange.shade400],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Center(
                  child: Icon(
                    isIncoming ? Icons.login_rounded : Icons.logout_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      observerName,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      Icons.school_rounded,
                      isIncoming ? 'From' : 'Going to',
                      schoolName,
                    ),
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(Icons.phone_rounded, 'Contact', phone),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: Colors.blue.shade900.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernAppBar() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    const double barContentHeight = 52.0;

    return SliverAppBar(
      expandedHeight: statusBarHeight + barContentHeight,
      toolbarHeight: barContentHeight,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue.shade900,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade700],
            ),
          ),
          padding: EdgeInsets.fromLTRB(16, statusBarHeight, 16, 0),
          child: Row(
            children: [
              // Profile Section
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  ).then((_) => _loadUserData());
                },
                child: Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.blue.shade100],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage:
                          _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                      child:
                          _profileImageUrl == null
                              ? Icon(
                                Icons.person,
                                color: Colors.blue.shade900,
                                size: 24,
                              )
                              : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // School Name - Expanded to take remaining space and prevent overflow
              Expanded(
                child: Text(
                  _schoolDisplayName,
                  style: GoogleFonts.poppins(
                    fontSize: 16.0,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              // Action Buttons Section
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderIconButton(
                    StreamBuilder<List<QuerySnapshot>>(
                      stream:
                          _notificationStream ??
                          Rx.combineLatest2(
                            FirebaseFirestore.instance
                                .collection('notifications')
                                .where(
                                  'recipientId',
                                  isEqualTo:
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      'INVALID',
                                )
                                .snapshots(),
                            FirebaseFirestore.instance
                                .collection('broadcasts')
                                .snapshots(),
                            (QuerySnapshot a, QuerySnapshot b) => [a, b],
                          ).asBroadcastStream(),
                      builder: (context, snapshot) {
                        int unreadCount = 0;
                        if (snapshot.hasData && snapshot.data != null) {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final allDocs = [
                              ...snapshot.data![0].docs,
                              ...snapshot.data![1].docs,
                            ];
                            unreadCount =
                                allDocs.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>?;
                                  final readBy =
                                      data?['readBy'] as List<dynamic>? ?? [];
                                  return !readBy.contains(user.uid);
                                }).length;
                          }
                        }
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.notifications_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  if (_isAdmin) const SizedBox(width: 8),
                  if (_isAdmin)
                    _buildHeaderIconButton(
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminDashboardScreen(),
                          ),
                        );
                      },
                    ),
                  const SizedBox(width: 8),
                  _buildHeaderIconButton(
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    _logout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton(Widget icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(77), width: 1),
        ),
        child: icon,
      ),
    );
  }

  Widget _buildActiveProgramsBanner() {
    if (_activeProgramsStream == null) {
      _setupActiveProgramsStream();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _activeProgramsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final activePrograms = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final endDate = (data['endDate'] as Timestamp?)?.toDate();
          return endDate != null && endDate.isAfter(now);
        }).toList();

        if (activePrograms.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort by startDate descending to show the most recent one
        activePrograms.sort((a, b) {
          final aStart =
              (a.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
          final bStart =
              (b.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
          if (aStart == null || bStart == null) return 0;
          return bStart.compareTo(aStart);
        });

        final latestProgram =
            activePrograms.first.data() as Map<String, dynamic>;
        final String programName = latestProgram['name'] ?? 'New Program';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegistrationDashboard(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade700, Colors.purple.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.shade900.withAlpha(77),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registration Open!',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          programName,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade400.withAlpha(77),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Highlight Event',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const HighlightEventCard(),
        ],
      ),
    );
  }

  Widget _buildRecentEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Recent Events',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showSortDialog,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade900.withAlpha(51),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: Colors.blue.shade900,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildModernCategoryFilter(),
        const SizedBox(height: 16),
        _buildSearchBox(),
        const SizedBox(height: 16),
        _buildRecentEventsList(),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '© ${DateTime.now().year} AJCE. All Rights Reserved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildModernCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.blue.shade900.withAlpha(26),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(
                _selectedCategoryIndex == 0
                    ? -1.0
                    : (_selectedCategoryIndex == 1 ? 0.0 : 1.0),
                0,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: Container(
                width: (MediaQuery.of(context).size.width - 40) / 3,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade900.withAlpha(77),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: List.generate(_categories.length, (index) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedCategoryIndex = index);
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Text(
                          _categories[index],
                          style: GoogleFonts.poppins(
                            color: _selectedCategoryIndex == index
                                ? Colors.white
                                : Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.blue.shade900.withAlpha(26),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search events...',
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.blue.shade900,
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentEventsList() {
    if (_eventsStream == null) {
      _setupEventsStream();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: EventListSkeleton(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final allDocs = snapshot.data!.docs;
        final selectedCategory = _categories[_selectedCategoryIndex];
        List<DocumentSnapshot> filteredDocs = allDocs;

        if (selectedCategory != 'ALL') {
          filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['category']?.toString().toUpperCase() ?? '') ==
                selectedCategory;
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery);
          }).toList();
        }

        if (_currentSortOption == SortOption.alphabetical) {
          filteredDocs.sort((a, b) {
            String aTitle =
                (a.data() as Map<String, dynamic>)['title']
                    ?.toString()
                    .toLowerCase() ??
                '';
            String bTitle =
                (b.data() as Map<String, dynamic>)['title']
                    ?.toString()
                    .toLowerCase() ??
                '';
            return aTitle.compareTo(bTitle);
          });
        }

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: filteredDocs.asMap().entries.map((entry) {
              int index = entry.key;
              var eventDoc = entry.value;
              return _buildEventCard(eventDoc, index);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(DocumentSnapshot eventDoc, int index) {
    var data = eventDoc.data() as Map<String, dynamic>;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8), // Glassmorphic
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFE4B5).withOpacity(0.4), // Soft Gold Border
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.12), // Warm Shadow
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(eventId: eventDoc.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Hero(
                    tag: data['imageUrl'] != null
                        ? 'event_image_${eventDoc.id}'
                        : 'event_icon_${eventDoc.id}',
                    child: Builder(
                      builder: (context) {
                        final placeholder = HomeScreen.getEventPlaceholderData(
                          data['category'] ?? '',
                        );
                        final String? imageUrl = data['imageUrl'];
                        final bool hasImage =
                            imageUrl != null &&
                            imageUrl.isNotEmpty &&
                            !imageUrl.contains('via.placeholder.com');

                        return Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: hasImage
                                ? null
                                : placeholder['gradient'] as LinearGradient?,
                            color: hasImage ? Colors.grey.shade100 : null,
                            boxShadow: [
                              BoxShadow(
                                color: (placeholder['color'] as Color)
                                    .withAlpha(80),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: hasImage
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: 160,
                                    cacheHeight: 160,
                                    errorBuilder: (ctx, err, st) => Container(
                                      decoration: BoxDecoration(
                                        gradient:
                                            placeholder['gradient']
                                                as LinearGradient?,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          placeholder['icon'] as IconData?,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      placeholder['icon'] as IconData?,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['title'] ?? 'No Title',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (data['category'] != null)
                              Builder(
                                builder: (context) {
                                  final isCml =
                                      data['category']
                                          ?.toString()
                                          .toUpperCase() ==
                                      'CML';
                                  // CML = deep violet, SUVARA = golden amber
                                  final badgeBg = isCml
                                      ? const Color(0xFFF0EBFF)
                                      : const Color(0xFFFFF8E1);
                                  final badgeBorder = isCml
                                      ? const Color(0xFFB39DDB)
                                      : const Color(0xFFFFCC02);
                                  final badgeText = isCml
                                      ? const Color(0xFF4527A0)
                                      : const Color(0xFF8D6200);
                                  return IntrinsicWidth(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: badgeBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        data['category']
                                                ?.toString()
                                                .toUpperCase() ??
                                            '',
                                        softWrap: false,
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: badgeText,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['description'] ?? 'No Description',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatEventTime(data['timestamp'] as Timestamp?),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.blue.shade900.withAlpha(128),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.event_busy_rounded,
                size: 64,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching events'
                  : 'No events found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Create your first event to get started',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// HighlightEventCard with modern design
class HighlightEventCard extends StatefulWidget {
  const HighlightEventCard({super.key});
  @override
  State<HighlightEventCard> createState() => _HighlightEventCardState();
}

class _HighlightEventCardState extends State<HighlightEventCard> {
  late final Stream<QuerySnapshot> _highlightStream;

  @override
  void initState() {
    super.initState();
    _highlightStream = _createHighlightStream();
  }

  Stream<QuerySnapshot> _createHighlightStream() {
    final user = FirebaseAuth.instance.currentUser;
    Query baseQuery = FirebaseFirestore.instance.collection('events');

    if (user != null) {
      baseQuery = baseQuery.where('creatorId', isEqualTo: user.uid);
    }

    return baseQuery
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _highlightStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade100, Colors.blue.shade200],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade900.withAlpha(51),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 48,
                    color: Colors.blue.shade900,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No highlight event",
                    style: GoogleFonts.poppins(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        var eventDoc = snapshot.data!.docs.first;
        var data = eventDoc.data() as Map<String, dynamic>;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EventDetailScreen(eventId: eventDoc.id),
              ),
            );
          },
          child: Hero(
            tag: 'highlight_${eventDoc.id}',
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade900.withAlpha(77),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (data['imageUrl'] != null)
                      Image.network(
                        data['imageUrl']!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          final placeholder =
                              HomeScreen.getEventPlaceholderData(
                                data['category'] ?? '',
                              );
                          return Container(
                            decoration: BoxDecoration(
                              gradient:
                                  placeholder['gradient'] as LinearGradient?,
                            ),
                            child: Center(
                              child: Icon(
                                placeholder['icon'] as IconData?,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Builder(
                        builder: (context) {
                          final placeholder =
                              HomeScreen.getEventPlaceholderData(
                                data['category'] ?? '',
                              );
                          return Container(
                            decoration: BoxDecoration(
                              gradient:
                                  placeholder['gradient'] as LinearGradient?,
                            ),
                            child: Center(
                              child: Icon(
                                placeholder['icon'] as IconData?,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(204),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data['category'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withAlpha(77),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                data['category']?.toString().toUpperCase() ??
                                    '',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            data['title'] ?? 'No Title',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 12.0,
                                  color: Colors.black.withAlpha(128),
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Modern EventListSkeleton
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget buildShimmerBlock({
      required double height,
      double width = double.infinity,
      double radius = 16.0,
    }) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(5, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                buildShimmerBlock(height: 80, width: 80, radius: 16),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildShimmerBlock(height: 18, width: double.infinity),
                      const SizedBox(height: 8),
                      buildShimmerBlock(height: 14, width: 200),
                      const SizedBox(height: 8),
                      buildShimmerBlock(height: 12, width: 120),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
