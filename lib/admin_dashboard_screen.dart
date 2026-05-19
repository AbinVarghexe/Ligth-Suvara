import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sundayschool_app/admin_notification_screen.dart';
import 'package:sundayschool_app/event_detail_screen.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/login_screen.dart';
import 'package:sundayschool_app/services/notification_service.dart';
import 'package:sundayschool_app/admin/admin_animator_menu.dart';
import 'package:sundayschool_app/admin/admin_program_menu.dart';
import 'package:sundayschool_app/admin/admin_parish_menu.dart';
import 'package:sundayschool_app/admin/admin_school_menu.dart';
import 'package:sundayschool_app/admin/admin_all_events_screen.dart';
import 'package:sundayschool_app/widgets/heavenly_background.dart';

enum SortOption { newestFirst, alphabetical }

class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget buildShimmerBlock({
      required double height,
      double width = double.infinity,
      double radius = 15.0,
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
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
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
                        buildShimmerBlock(height: 20, width: 200),
                        const SizedBox(height: 8),
                        buildShimmerBlock(height: 16, width: 150),
                        const SizedBox(height: 8),
                        buildShimmerBlock(height: 14, width: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdminStatsSkeleton extends StatelessWidget {
  const AdminStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildSkeletonCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildSkeletonCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildSkeletonCard()),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      height: 170,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.3),
            highlightColor: Colors.white.withValues(alpha: 0.8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 38,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['ALL', 'CML', 'SUVARA'];
  SortOption _currentSortOption = SortOption.newestFirst;

  int _totalEvents = 0;
  int _publicEvents = 0;
  int _draftEvents = 0;

  bool _isStatsLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _fetchAndSetStatistics();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndSetStatistics() async {
    if (_isStatsLoading) return;
    if (mounted) setState(() => _isStatsLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance.collection('events').get();
      final allEvents = snapshot.docs;
      final total = allEvents.length;
      final public = allEvents.where((doc) => (doc.data())['isPublic'] == true).length;
      final draft = total - public;

      if (mounted) {
        setState(() {
          _totalEvents = total;
          _publicEvents = public;
          _draftEvents = draft;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load statistics: $e'), backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.sort, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text('Sort Events', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue.shade900)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSortOption('Newest First', Icons.access_time, SortOption.newestFirst, context),
                const SizedBox(height: 12),
                _buildSortOption('Alphabetical (A-Z)', Icons.sort_by_alpha, SortOption.alphabetical, context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, IconData icon, SortOption value, BuildContext context) {
    final isSelected = _currentSortOption == value;
    return InkWell(
      onTap: () {
        setState(() => _currentSortOption = value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.blue.shade900 : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.blue.shade900),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: GoogleFonts.outfit(color: isSelected ? Colors.white : Colors.blue.shade900, fontWeight: FontWeight.w600))),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: _isStatsLoading
          ? const AdminStatsSkeleton()
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildGradientStatCard('Total Events', _totalEvents, Icons.event_note_rounded, [Colors.blue.shade700, Colors.blue.shade900])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGradientStatCard('Public', _publicEvents, Icons.public_rounded, [Colors.green.shade600, Colors.green.shade800])),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGradientStatCard('Drafts', _draftEvents, Icons.drafts_rounded, [Colors.orange.shade600, Colors.orange.shade800])),
                ],
              ),
            ),
    );
  }

  Widget _buildGradientStatCard(String title, int count, IconData icon, List<Color> gradientColors) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutQuart,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.6), // Luminous peak
                        Colors.white.withValues(alpha: 0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55), // Bright Luminous edge
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: -8,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [gradientColors[0], gradientColors[1]],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: gradientColors[0].withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        (count * value).toInt().toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 38, 
                          fontWeight: FontWeight.w900, 
                          color: const Color(0xFF1E293B), // Deep Midnight
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.5), 
                              offset: const Offset(1, 1), 
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title, 
                        style: GoogleFonts.outfit(
                          fontSize: 14, 
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8), // High-visibility label
                          fontWeight: FontWeight.w800, 
                          letterSpacing: 0.8,
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
    );
  }

  Widget _buildModernCategoryFilter() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65), // Luminous frosted base
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), 
                blurRadius: 25, 
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_categories.length, (index) {
              final isSelected = _selectedCategoryIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _selectedCategoryIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.fastOutSlowIn,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: isSelected 
                        ? const LinearGradient(
                            colors: [Color(0xFFD4AF37), Color(0xFFF9D423)], 
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ) 
                        : null,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: isSelected 
                        ? [BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.45), blurRadius: 15, offset: const Offset(0, 6))] 
                        : null,
                    ),
                    child: Center(
                      child: Text(
                        _categories[index], 
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? Colors.black87 : const Color(0xFF1E293B).withValues(alpha: 0.6), // High-visibility inactive
                          fontWeight: FontWeight.w900, 
                          fontSize: 15,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  int _selectedIndex = 0;
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        title: Text('Logout', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          NotificationService().unsubscribeAll(user.uid, userDoc.data()?['role']?.toString()).catchError((e) => debugPrint(e.toString()));
        } catch (e) { debugPrint(e.toString()); }
      }
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: HeavenlyBackground(
        showImage: true,
        child: Stack(
          children: [
            SafeArea(bottom: false, child: _buildBody()),
            Align(alignment: Alignment.bottomCenter, child: _bottomNav()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeTabContent(),
        const AdminAnimatorMenu(),
        const AdminProgramMenu(),
        const AdminParishMenu(),
        const AdminSchoolMenu(),
      ],
    );
  }

  Widget _buildHomeTabContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _glassHeader(),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFF9D423), Color(0xFFD4AF37)],
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ).createShader(bounds),
              child: Text(
                "Event Management",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white, // Colors will be masked by ShaderMask
                  letterSpacing: -1.0, // Modern tight spacing
                  shadows: [
                    Shadow(color: Colors.black.withValues(alpha: 0.4), offset: const Offset(1, 2), blurRadius: 6),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Manage and monitor all events",
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E293B).withValues(alpha: 0.85), 
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2, // Airy modern vibe
              ),
            ),
            const SizedBox(height: 28),
            _buildStatisticsCards(const Color(0xFF1F3C88)),
            const SizedBox(height: 28),
            _buildModernCategoryFilter(),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Latest Events", 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26, 
                    fontWeight: FontWeight.w900, 
                    color: const Color(0xFF1E293B), // High-visibility Midnight Blue
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAllEventsScreen())),
                  child: Text(
                    "View All", 
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFD4AF37), 
                      fontWeight: FontWeight.w900, 
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAllEventsList(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildAllEventsList() {
    final selectedCategory = _categories[_selectedCategoryIndex];
    Query baseQuery = FirebaseFirestore.instance.collection('events').orderBy('timestamp', descending: true);
    if (selectedCategory != 'ALL') baseQuery = baseQuery.where('category', isEqualTo: selectedCategory.toLowerCase());

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.limit(3).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const EventListSkeleton();
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No events found", style: TextStyle(color: Colors.white70))));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var eventDoc = docs[index];
            var data = eventDoc.data() as Map<String, dynamic>;
            bool isPublic = data['isPublic'] ?? false;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 25 * (1 - value)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.65), // Milky Luminous Visibility
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.8),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventDoc.id))),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: 'event_image_${eventDoc.id}',
                                    child: Container(
                                      width: 75, height: 75,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 5))],
                                        image: data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty ? DecorationImage(image: NetworkImage(data['imageUrl']), fit: BoxFit.cover) : null,
                                        gradient: data['imageUrl'] == null || (data['imageUrl'] as String).isEmpty ? HomeScreen.getEventPlaceholderData(data['category'] ?? '')['gradient'] as LinearGradient? : null,
                                      ),
                                      child: data['imageUrl'] == null || (data['imageUrl'] as String).isEmpty ? Center(child: Icon(HomeScreen.getEventPlaceholderData(data['category'] ?? '')['icon'] as IconData?, color: Colors.white, size: 32)) : null,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['title'] ?? 'No Title', 
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w900, 
                                            fontSize: 19, 
                                            color: const Color(0xFF1E293B), // High-visibility project title
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isPublic ? Colors.green.shade500.withValues(alpha: 0.15) : Colors.amber.shade700.withValues(alpha: 0.12), 
                                            borderRadius: BorderRadius.circular(12), 
                                            border: Border.all(color: isPublic ? Colors.green.shade600.withValues(alpha: 0.6) : Colors.amber.shade800.withValues(alpha: 0.7), width: 1.2),
                                          ),
                                          child: Text(
                                            isPublic ? "Published" : "Draft", 
                                            style: GoogleFonts.plusJakartaSans(
                                              color: isPublic ? Colors.green.shade700 : Colors.amber.shade900, 
                                              fontSize: 12, 
                                              fontWeight: FontWeight.w900, 
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: const Color(0xFF1E293B).withValues(alpha: 0.5), size: 34),
                                ],
                              ),
                            ),
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

  Widget _glassHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.7),
                Colors.white.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🔄 Left Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppBarAction(
                    icon: Icons.refresh_rounded, 
                    color: _isStatsLoading ? Colors.black26 : Colors.black87, 
                    onPressed: _isStatsLoading ? null : _fetchAndSetStatistics, 
                    tooltip: 'Refresh Statistics',
                  ),
                  _buildAppBarAction(
                    icon: Icons.notifications_active_rounded, 
                    color: Colors.black87, 
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminNotificationScreen())), 
                    tooltip: 'Send Notification',
                  ),
                ],
              ),
              
              // ✨ Center Logo (Adaptive)
              Expanded(
                child: Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        "assets/images/new_logo_light.png",
                        height: 44, // Slightly smaller for better fit
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // ⚙️ Right Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppBarAction(
                    icon: Icons.sort_rounded, 
                    color: Colors.black87, 
                    onPressed: _showSortDialog, 
                    tooltip: 'Sort Events',
                  ),
                  const SizedBox(width: 4),
                  _buildHeaderIconButton(
                    const Icon(Icons.logout_rounded, color: Color(0xFF1E3A8A), size: 22), 
                    _handleLogout,
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(77), width: 1),
        ),
        child: icon,
      ),
    );
  }

  Widget _bottomNav() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35), // Higher visibility 'milky' glass
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 0, "Home"),
                _navItem(Icons.supervised_user_circle_rounded, 1, "Animator"),
                _navItem(Icons.event_note_rounded, 2, "Program"),
                _navItem(Icons.church_rounded, 3, "Parish"),
                _navItem(Icons.school_rounded, 4, "School"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onItemTapped(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
            ? Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.0) 
            : null,
        ),
        child: Icon(
          icon, 
          color: isSelected ? const Color(0xFFB8860B) : const Color(0xFF1E293B).withValues(alpha: 0.6), // Rich Gold vs Midnight Blue
          size: 26,
        ),
      ),
    );
  }

  Widget _buildAppBarAction({required IconData icon, required Color color, required VoidCallback? onPressed, required String tooltip}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(8.0), // More compact than IconButton's 48px
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

}
