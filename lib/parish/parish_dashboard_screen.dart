import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:rxdart/rxdart.dart'; // Added Import

class ParishDashboardScreen extends StatefulWidget {
  const ParishDashboardScreen({super.key});

  @override
  State<ParishDashboardScreen> createState() => _ParishDashboardScreenState();
}

class _ParishDashboardScreenState extends State<ParishDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  String? _linkedSchoolId;
  String? _parishName;
  int _selectedIndex = 0; // 0: Events, 1: Registrations
  bool _isLoading = true;

  // Streams for registrations
  Stream<QuerySnapshot>? _pendingStream;
  Stream<QuerySnapshot>? _approvedStream;

  // Stream for notifications
  Stream<List<QuerySnapshot>>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            });

            // Subscribe to linked school notifications
            NotificationService().subscribeToUserTopic(schoolId);
            NotificationService().subscribeToRoleTopic('school');

            // Setup notification stream
            _notificationStream = Rx.combineLatest2(
              FirebaseFirestore.instance
                  .collection('notifications')
                  .where(
                    'recipientId',
                    whereIn: [schoolId, 'school_$schoolId', 'role_school'],
                  )
                  .snapshots(),
              FirebaseFirestore.instance.collection('broadcasts').snapshots(),
              (QuerySnapshot a, QuerySnapshot b) => [a, b],
            );
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

    // Unsubscribe from school notifications before logging out
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      body: _selectedIndex == 0
          ? _buildSchoolEventsView()
          : _buildRegistrationsView(),
      extendBody: true, // Needed for floating nav bar to overlay body
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade900.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
            // Outer border for the glass effect
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.white.withOpacity(0.8), // Semi-transparent white
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
                color: Colors.blue.shade900.withOpacity(0.3),
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
                    fontSize: 24,
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
    return StreamBuilder<List<QuerySnapshot>>(
      stream:
          _notificationStream ??
          Rx.combineLatest2(
            FirebaseFirestore.instance
                .collection('notifications')
                .where(
                  'recipientId',
                  isEqualTo: _auth.currentUser?.uid ?? 'INVALID',
                )
                .snapshots(),
            FirebaseFirestore.instance.collection('broadcasts').snapshots(),
            (QuerySnapshot a, QuerySnapshot b) => [a, b],
          ),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData && snapshot.data != null) {
          final user = _auth.currentUser;
          if (user != null) {
            final allDocs = [
              ...snapshot.data![0].docs,
              ...snapshot.data![1].docs,
            ];
            unreadCount = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
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
                    color: Colors.blue.shade900.withOpacity(0.05),
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
                        color: Colors.red.withOpacity(0.4),
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
              color: Colors.blue.shade900.withOpacity(0.3),
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
            child: _buildModernHeader(
              title: _parishName ?? 'Dashboard',
              subtitle: 'WELCOME BACK',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _buildHighlightSection(),
            ),
          ),
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
                ],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .where('creatorId', isEqualTo: _linkedSchoolId)
                .orderBy('timestamp', descending: true)
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
                                        child: data['imageUrl'] != null
                                            ? Image.network(
                                                data['imageUrl'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (ctx, err, st) =>
                                                    Icon(
                                                      Icons.image_rounded,
                                                      color:
                                                          Colors.blue.shade900,
                                                      size: 32,
                                                    ),
                                              )
                                            : Icon(
                                                Icons.image_rounded,
                                                color: Colors.blue.shade900,
                                                size: 32,
                                              ),
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
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final programName = data['programName'] ?? 'Unknown Program';

          final isCountOnly = data['isCountOnly'] == true;
          final studentCount = isCountOnly
              ? (data['studentCount'] as int? ?? 1)
              : 1;

          programCounts[programName] =
              (programCounts[programName] ?? 0) + studentCount;
        }

        final programs = programCounts.keys.toList();
        programs.sort(); // Alphabetical sort

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: programs.length,
          itemBuilder: (context, index) {
            final programName = programs[index];
            final count = programCounts[programName];

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
                        vertical: 12,
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
                                  '$count Student${count == 1 ? '' : 's'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
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
                    Image.network(
                      data['imageUrl'] ??
                          'https://via.placeholder.com/400x220?text=No+Image',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade300,
                                Colors.blue.shade500,
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_rounded,
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
