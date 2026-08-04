import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart'; // Added shimmer
import 'dart:ui'; // Added Import for BackdropFilter
import 'package:sundayschool_app/login_screen.dart';
import 'package:sundayschool_app/event_detail_screen_from_home.dart';
import 'package:sundayschool_app/parish/parish_program_list_screen.dart';
import 'package:sundayschool_app/services/notification_service.dart'; // Added Import
import 'package:sundayschool_app/notification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sundayschool_app/parish/parish_all_events_screen.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/models/program_payment_details.dart';


class ParishDashboardScreen extends StatefulWidget {
  const ParishDashboardScreen({super.key});

  @override
  State<ParishDashboardScreen> createState() => _ParishDashboardScreenState();
}

class _ParishDashboardScreenState extends State<ParishDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  String? _linkedSchoolId;
  String? _parishName;
  int _selectedIndex = 0; // 0: Events, 1: Registrations
  bool _isLoading = true;
  bool _isObserverMinimized = false;
  bool _isObserverCollapsed = false;

  // Streams for registrations
  Stream<QuerySnapshot>? _pendingStream;
  Stream<QuerySnapshot>? _approvedStream;

  // Streams for notifications
  Stream<QuerySnapshot>? _userNotificationsStream;
  Stream<QuerySnapshot>? _broadcastsStream;
  late Stream<List<QuerySnapshot>> _observerAssignmentsStream;
  late AnimationController _pulseController; // Added for loader

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initializeData();
    _loadObserverPreference();
  }

  Future<void> _loadObserverPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isObserverMinimized =
            prefs.getBool('observer_minimized_parish') ?? false;
        _isObserverCollapsed =
            prefs.getBool('observer_collapsed_parish') ?? false;
      });
    }
  }

  Future<void> _saveObserverPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('observer_minimized_parish', _isObserverMinimized);
    await prefs.setBool('observer_collapsed_parish', _isObserverCollapsed);
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
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose(); // Added dispose
    super.dispose();
  }

  Future<void> _initializeData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache));

        if (userDoc.exists) {
          final data = userDoc.data();
          final String? schoolId = data?['schoolId'];

          if (schoolId != null) {
            setState(() {
              _linkedSchoolId = schoolId;
              _parishName = data?['name'] ?? data?['schoolName'];

              _pendingStream = FirebaseFirestore.instance
                  .collection('program_registrations')
                  .where('schoolUserId', isEqualTo: schoolId)
                  .where('status', isEqualTo: 'pending_parish')
                  .snapshots();

              _approvedStream = FirebaseFirestore.instance
                  .collection('program_registrations')
                  .where('schoolUserId', isEqualTo: schoolId)
                  .where(
                    'status',
                    whereIn: ['approved_parish', 'locked'],
                  ) // Include locked
                  .snapshots();

              // Initialize observer assignments stream
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
            });

            // Subscribe to linked school notifications
            NotificationService().subscribeToUserTopic(schoolId);
            NotificationService().subscribeToRoleTopic('school');

            // Setup notification streams
            _userNotificationsStream = FirebaseFirestore.instance
                .collection('notifications')
                .where(
                  'recipientId',
                  whereIn: [
                    user.uid,
                    schoolId,
                    'school_$schoolId',
                    'role_school',
                  ],
                )
                .snapshots();
            _broadcastsStream = FirebaseFirestore.instance
                .collection('broadcasts')
                .snapshots();
          } else {
            debugPrint("Parish User has no linked schoolId.");
          }
        }
      } catch (e) {
        debugPrint("Error initializing data: $e");
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Confirm Logout',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to log out of your account?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      if (_linkedSchoolId != null) {
        NotificationService().unsubscribeFromUserTopic(_linkedSchoolId!);
        NotificationService().unsubscribeFromRoleTopic('school');
      }

      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Widget _buildHeavenlyLoadingScreen() {
    return Scaffold(
      body: Stack(
        children: [
          // 🌊 Cosmic Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.blue.shade50,
                  Colors.indigo.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 🌫️ Bokeh Particles (Stationary but elegant)
          ...List.generate(5, (index) {
            final double x = [0.2, 0.8, 0.5, 0.3, 0.7][index % 5];
            final double y = [0.2, 0.3, 0.6, 0.8, 0.7][index % 5];
            final double size = [150.0, 200.0, 250.0, 180.0, 220.0][index % 5];
            final Color color = [
              Colors.blue.shade100,
              Colors.orange.shade50,
              Colors.indigo.shade100,
              Colors.white,
              Colors.blue.shade50,
            ][index % 5];

            return Positioned(
              left: MediaQuery.of(context).size.width * x - (size / 2),
              top: MediaQuery.of(context).size.height * y - (size / 2),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withOpacity(0),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ✨ Central Crystalline Loader
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double pulse = 1.0 + (0.05 * _pulseController.value);
                return Transform.scale(
                  scale: pulse,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(
                                0.5 * _pulseController.value,
                              ),
                              blurRadius: 30,
                              spreadRadius: -2,
                            ),
                            BoxShadow(
                              color: Colors.blue.shade400.withOpacity(
                                0.15 * _pulseController.value,
                              ),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Image.asset(
                              'assets/images/applogo3.png',
                              height: 100,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Opacity(
                        opacity: 0.3 + (0.4 * _pulseController.value),
                        child: Text(
                          'HEAVENLY EXPERIENCE',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: Colors.indigo.shade900,
                          ),
                        ),
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

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildHeavenlyLoadingScreen();
    }

    if (_linkedSchoolId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Parish Dashboard"),

          automaticallyImplyLeading: false,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.amber),
              const SizedBox(height: 16),
              const Text("No linked school found"),
              TextButton(onPressed: _logout, child: const Text("Logout")),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [_buildSchoolEventsView(), _buildRegistrationsView()],
          ),
          if (_selectedIndex == 0 && _isObserverMinimized)
            _buildFloatingObserverButton(),
        ],
      ),
      extendBody: true, // Needed for floating nav bar to overlay body
      bottomNavigationBar: SafeArea(
        bottom: false,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade900.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
            // Outer border for the glass effect
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.white.withValues(
                  alpha: 0.8,
                ), // Semi-transparent white
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  selectedItemColor: Colors.blue.shade900,
                  unselectedItemColor: Colors.grey.shade600,
                  selectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent, // Very important
                  elevation: 0,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Icon(Icons.calendar_today_rounded),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Icon(Icons.calendar_month_rounded),
                      ),
                      label: 'School Events',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Icon(Icons.assignment_outlined),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Icon(Icons.assignment_rounded),
                      ),
                      label: 'Approvals',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationsView() {
    return SafeArea(
      child: Column(
        children: [
          _buildModernHeader(title: 'Registrations'),
          const SizedBox(height: 16),
          _buildSegmentedControl(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProgramGroups(_pendingStream, ['pending_parish']),
                _buildProgramGroups(_approvedStream, [
                  'approved_parish',
                  'locked',
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(25),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          indicator: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade900.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent, // Remove default underline
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader({required String title, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle,
                    style:
                        GoogleFonts.poppins(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 1.1,
                        ).copyWith(
                          foreground: Paint()
                            ..shader =
                                LinearGradient(
                                  colors: [
                                    Colors.blue.shade900,
                                    Colors.blue.shade600,
                                  ],
                                ).createShader(
                                  const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                                ),
                        ),
                  ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildNotificationBell(),
              const SizedBox(width: 12),
              _buildProfileIcon(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _userNotificationsStream ??
          FirebaseFirestore.instance
              .collection('notifications')
              .where(
                'recipientId',
                isEqualTo: _auth.currentUser?.uid ?? 'INVALID',
              )
              .snapshots(),
      builder: (context, notifSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              _broadcastsStream ??
              FirebaseFirestore.instance.collection('broadcasts').snapshots(),
          builder: (context, broadSnapshot) {
            int unreadCount = 0;
            if (notifSnapshot.hasData && broadSnapshot.hasData) {
              final user = _auth.currentUser;
              if (user != null) {
                final allDocs = [
                  ...notifSnapshot.data!.docs,
                  ...broadSnapshot.data!.docs,
                ];
                unreadCount = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data?['notificationOnly'] == true) return false;
                  final readBy = data?['readBy'] as List<dynamic>? ?? [];
                  return !readBy.contains(user.uid);
                }).length;
              }
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: Colors.blue.shade900,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: GoogleFonts.poppins(
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
        );
      },
    );
  }

  Widget _buildProfileIcon() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Since there is no profile screen directly applicable here yet,
        // we map it to quick logout for the moment. Will refine later if needed.
        _logout();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade900.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons
              .logout_rounded, // Assuming Logout represents profile action for Parish
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildHighlightSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const SizedBox(height: 16),
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
          HighlightEventCard(schoolId: _linkedSchoolId),
        ],
      ),
    );
  }

  Widget _buildSchoolEventsView() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildModernHeader(title: _parishName ?? 'Dashboard'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildHighlightSection(),
            ),
          ),
          if (!_isObserverMinimized) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildObserverSection()),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade900],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade900.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.event_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Events',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ParishAllEventsScreen(
                            linkedSchoolId: _linkedSchoolId,
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    label: Text(
                      'See All',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .where('creatorId', isEqualTo: _linkedSchoolId)
                .orderBy('timestamp', descending: true)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
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
                            Icons.event_busy_rounded,
                            size: 64,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No events found',
                          style: GoogleFonts.poppins(
                            color: Colors.blue.shade900,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String eventId = docs[index].id;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 100)),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blue.shade900.withAlpha(26),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(13),
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EventDetailScreenFromHome(
                                        eventId: eventId,
                                      ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: 'event_$eventId',
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade100,
                                            Colors.blue.shade200,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.shade900
                                                .withAlpha(51),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: () {
                                          final String category =
                                              data['category']?.toString() ??
                                              '';
                                          final String? imageUrl =
                                              data['imageUrl'];
                                          final bool hasValidImage =
                                              imageUrl != null &&
                                              imageUrl.isNotEmpty &&
                                              !imageUrl.contains(
                                                'via.placeholder.com',
                                              );
                                          final placeholder =
                                              _buildParishImagePlaceholderWidget(
                                                category: category,
                                              );

                                          if (!hasValidImage)
                                            return placeholder;

                                          if (imageUrl.startsWith(
                                            'data:image/',
                                          )) {
                                            try {
                                              final bytes = base64Decode(
                                                imageUrl.split(',').last,
                                              );
                                              return Image.memory(
                                                bytes,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    placeholder,
                                              );
                                            } catch (_) {
                                              return placeholder;
                                            }
                                          }

                                          return Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    placeholder,
                                          );
                                        }(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['title'] ?? 'Untitled Event',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.blue.shade900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 14,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                data['place'] ??
                                                    'Unknown location',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
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
                                              _formatEventTime(
                                                data['timestamp'] as Timestamp?,
                                              ),
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
                                    color: Colors.blue.shade900.withOpacity(
                                      0.5,
                                    ),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: docs.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObserverSection() {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
        FirebaseFirestore.instance
            .collection('assignments')
            .where('type', isEqualTo: 'Observer')
            .snapshots(),
        FirebaseFirestore.instance
            .collection('settings')
            .doc('observer_dates')
            .collection('years')
            .snapshots(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final assignmentsData = snapshot.data![0];
        final settingsData = snapshot.data![1];

        if (assignmentsData.docs.isEmpty) {
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
          if (data['targetSchoolId'] != _linkedSchoolId) return false;
          if (isExpired(data['academicYear'])) return false;
          return true;
        }).toList();

        final outgoing = assignmentsData.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['sourceSchoolId'] != _linkedSchoolId) return false;
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
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Observer Assignments',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.blue.shade900,
                                letterSpacing: -0.5,
                              ),
                            ),
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

          if (assignmentsData.docs.isEmpty) return const SizedBox.shrink();

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
            return data['targetSchoolId'] == _linkedSchoolId &&
                !isExpired(data['academicYear']);
          }).toList();

          final outgoing = assignmentsData.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['sourceSchoolId'] == _linkedSchoolId &&
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
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isIncoming ? Colors.indigo.shade100 : Colors.orange.shade100,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
            _showAssignmentDetails(
              title: title,
              observerName: observerName,
              schoolName: schoolName,
              isIncoming: isIncoming,
              phone: phone,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isIncoming
                        ? Colors.indigo.shade50
                        : Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncoming ? Icons.login_rounded : Icons.logout_rounded,
                    color: isIncoming
                        ? Colors.indigo.shade700
                        : Colors.orange.shade700,
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
                        isIncoming
                            ? 'From: $schoolName'
                            : 'Going to: $schoolName',
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
    final Color accentColor = isIncoming
        ? Colors.indigo.shade600
        : Colors.orange.shade600;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: const BorderSide(color: Colors.white, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            isIncoming
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ASSIGNMENT INFO',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      children: [
                        _buildBeautifulDetailRow(
                          Icons.person_rounded,
                          'Observer Name',
                          observerName,
                          Colors.blue.shade700,
                        ),
                        const SizedBox(height: 24),
                        _buildBeautifulDetailRow(
                          Icons.school_rounded,
                          isIncoming ? 'From School' : 'Target School',
                          schoolName,
                          Colors.indigo.shade700,
                        ),
                        if (phone != null && phone.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildBeautifulDetailRow(
                            Icons.phone_iphone_rounded,
                            'Contact Number',
                            phone,
                            Colors.green.shade700,
                            isPhone: true,
                          ),
                        ],
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade900,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.blue.shade900.withValues(
                                alpha: 0.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              'Got it',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.5,
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
      },
    );
  }

  Widget _buildBeautifulDetailRow(
    IconData icon,
    String label,
    String value,
    Color color, {
    bool isPhone = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade400,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
        ),
        if (isPhone)
          GestureDetector(
            onTap: () async {
              final url = Uri.parse('tel:$value');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_rounded,
                color: Colors.green,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgramGroups(
    Stream<QuerySnapshot>? stream,
    List<String> statuses,
  ) {
    if (stream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.blue.shade50.withValues(alpha: 0.8),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.inbox_rounded,
                    size: 56,
                    color: Colors.blue.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  statuses.contains('pending_parish')
                      ? 'All caught up!'
                      : 'No approved registrations',
                  style: GoogleFonts.poppins(
                    color: Colors.blue.shade900,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (statuses.contains('pending_parish')) ...[
                  const SizedBox(height: 8),
                  Text(
                    'There are no pending approvals right now.',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        // Group by Program Name
        final Map<String, int> programCounts = {};
        final Map<String, String> programTypes = {};
        final Map<String, List<QueryDocumentSnapshot>> programDocs = {};
        
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final programName = data['programName'] ?? 'Unknown Program';
          final type = data['type']?.toString() ?? 'student';

          final isCountOnly = data['isCountOnly'] == true;
          final studentCount = isCountOnly
              ? (data['studentCount'] as int? ?? 1)
              : 1;

          programCounts[programName] =
              (programCounts[programName] ?? 0) + studentCount;
          programTypes[programName] = type;
          
          if (!programDocs.containsKey(programName)) {
            programDocs[programName] = [];
          }
          programDocs[programName]!.add(doc);
        }

        final programs = programCounts.keys.toList();
        programs.sort(); // Alphabetical sort

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: programs.length,
          itemBuilder: (context, index) {
            final programName = programs[index];
            final count = programCounts[programName] ?? 0;
            final type = programTypes[programName] ?? 'student';
            final pDocs = programDocs[programName] ?? [];

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('programs')
                  .where('name', isEqualTo: programName)
                  .limit(1)
                  .get(),
              builder: (context, progSnapshot) {
                double amountPaid = 0.0;
                double amountToBePaid = 0.0;

                if (progSnapshot.hasData && progSnapshot.data!.docs.isNotEmpty) {
                  final progData = progSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                  if (progData['paymentDetails'] != null) {
                    final paymentDetails = ProgramPaymentDetails.fromMap(
                      Map<String, dynamic>.from(progData['paymentDetails']),
                    );

                    if (paymentDetails.isRequired) {
                      for (final doc in pDocs) {
                        final regData = doc.data() as Map<String, dynamic>;
                        final bool hasPaid = regData['paymentScreenshotUrl'] != null &&
                            (regData['paymentScreenshotUrl'] as String).isNotEmpty;
                        
                        final int studentCount = regData['isCountOnly'] == true
                            ? (regData['studentCount'] as int? ?? 1)
                            : 1;
                        
                        final double feePerPerson = paymentDetails.registrationFee;
                        final double advValue = paymentDetails.advanceValue;
                        final bool isFixed = paymentDetails.advanceType == 'fixed';
                        
                        final double targetAmount = isFixed
                            ? advValue
                            : (feePerPerson * advValue / 100);

                        if (hasPaid) {
                          amountPaid += targetAmount * studentCount;
                        } else {
                          amountToBePaid += targetAmount * studentCount;
                        }
                      }
                    }
                  }
                }

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 200 + (index * 50)),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blue.shade50.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade900.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ParishProgramListScreen(
                                schoolId: _linkedSchoolId!,
                                programName: programName,
                                statuses: statuses,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.blue.shade100.withValues(alpha: 0.5),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.school_rounded,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      programName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$count ${type == 'teacher' ? 'Teacher' : 'Student'}${count == 1 ? '' : 's'}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (amountPaid > 0 || amountToBePaid > 0) ...[
                                      const SizedBox(height: 6),
                                      FutureBuilder<QuerySnapshot>(
                                        future: FirebaseFirestore.instance
                                            .collection('programs')
                                            .where('name', isEqualTo: programName)
                                            .limit(1)
                                            .get(),
                                        builder: (context, rulesSnapshot) {
                                          if (rulesSnapshot.hasData && rulesSnapshot.data!.docs.isNotEmpty) {
                                            final pData = rulesSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                                            if (pData['paymentDetails'] != null) {
                                              final pd = ProgramPaymentDetails.fromMap(
                                                Map<String, dynamic>.from(pData['paymentDetails']),
                                              );
                                              final isFixed = pd.advanceType == 'fixed';
                                              final double advanceValue = pd.advanceValue;
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6.0),
                                                child: Text(
                                                  'Fee: ₹${pd.registrationFee.toStringAsFixed(0)} / person  •  ${isFixed ? 'Adv Required: ₹${advanceValue.toStringAsFixed(0)} / person' : 'Adv Required: ${advanceValue.toStringAsFixed(0)}%'}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade500,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Paid: ₹${amountPaid.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Pending: ₹${amountToBePaid.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.blue.shade900.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// HighlightEventCard adapted for Parish Dashboard (filters by schoolId)
class HighlightEventCard extends StatelessWidget {
  final String? schoolId;
  const HighlightEventCard({super.key, this.schoolId});

  @override
  Widget build(BuildContext context) {
    if (schoolId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('creatorId', isEqualTo: schoolId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
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
                // Use EventDetailScreenFromHome as defined in parent
                builder: (context) =>
                    EventDetailScreenFromHome(eventId: eventDoc.id),
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
                    () {
                      final String? imageUrl = data['imageUrl'];
                      final bool hasValidImage =
                          imageUrl != null &&
                          imageUrl.isNotEmpty &&
                          !imageUrl.contains('via.placeholder.com');
                      final placeholder = _buildParishImagePlaceholderWidget(
                        category: data['category']?.toString() ?? '',
                      );

                      if (!hasValidImage) return placeholder;

                      if (imageUrl.startsWith('data:image/')) {
                        try {
                          final bytes = base64Decode(imageUrl.split(',').last);
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => placeholder,
                          );
                        } catch (_) {
                          return placeholder;
                        }
                      }

                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            placeholder,
                      );
                    }(),
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

Widget _buildParishImagePlaceholderWidget({required String category}) {
  final placeholder = HomeScreen.getEventPlaceholderData(category);
  return Container(
    decoration: BoxDecoration(
      gradient: placeholder['gradient'] as LinearGradient?,
    ),
    child: Center(
      child: Icon(
        placeholder['icon'] as IconData?,
        size: 64,
        color: Colors.white,
      ),
    ),
  );
}
