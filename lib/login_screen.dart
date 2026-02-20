// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; // Required for ImageFilter
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:marquee/marquee.dart';
import 'package:sundayschool_app/utils/app_launcher.dart'; // Restored for Yamaprarthanakal
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Restored for icons
import 'package:sundayschool_app/auth_screen.dart'; // Added AuthScreen import
import 'package:google_fonts/google_fonts.dart';

// Assuming you have all these screen imports available
import 'package:sundayschool_app/broadcast_screen.dart';
import 'package:sundayschool_app/catechism_screen.dart';
// Note: This import was missing in your provided code but is used in the carousel.
// Ensure this file exists and is correct.

import 'package:sundayschool_app/bible.dart';
import 'package:sundayschool_app/japamala.dart';
import 'package:sundayschool_app/home_events.dart';

import 'package:sundayschool_app/programs_screen.dart';
import 'package:sundayschool_app/event_detail_screen_from_home.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:sundayschool_app/providers/content_provider.dart'; // Import ContentProvider
import 'package:shimmer/shimmer.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedIndex = 0; // 0: Home, 1: Resources, 2: Programs

  final List<String> topCarouselItems = const [
    'assets/images/marjosepulickal2.png',
    'assets/images/unnamed2.png',
    // Added duplicates to verify "Recent Programs" logic (skip 2)
    'assets/images/marjosepulickal2.png',
    'assets/images/unnamed2.png',
    'assets/images/marjosepulickal2.png',
  ];

  // --- Helper Widget for the Top Images (Side by Side) ---
  Widget _buildTopImagesHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCarouselItem(
              'assets/images/marjosepulickal2.png',
              '',
              isAsset: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCarouselItem(
              'assets/images/unnamed2.png',
              '',
              isAsset: true,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Carousel Item
  Widget _buildCarouselItem(
    String imageUrl,
    String title, {
    bool isAsset = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        color: Colors.white.withOpacity(
          0.8,
        ), // More opaque to match cream background
        border: Border.all(
          color: Color(0xFFFFE4B5).withOpacity(0.4),
          width: 1.5,
        ), // Soft gold border
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(
              0.12,
            ), // Warm shadow to match gold theme
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.orange.shade200.withOpacity(0.08),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5), // Inner radius (20 - 1.5)
        child: isAsset
            ? Image.asset(
                imageUrl,
                fit: BoxFit.contain, // Show full image without cropping
                alignment: Alignment.center,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image, color: Colors.grey[400]),
                ),
              ),
      ),
    );
  }

  // --- 1. NEW METHOD TO SHOW THE BOTTOM SHEET ---
  // lib/login_screen.dart

  // --- FIX: ADDED MISSING HELPER WIDGET ---
  // --- END OF ADDED HELPER WIDGET ---

  // Helper widget to build styled list tiles for the menu

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent, // Transparent to show gradient
        appBar: AppBar(
          backgroundColor: Colors.transparent, // Transparent AppBar
          elevation: 0,
          toolbarHeight: 60, // Retained large height
          leading: Container(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              'assets/images/diocese-logo-new1.png',
              height: 55,
              fit: BoxFit.contain,
            ),
          ),
          leadingWidth: 80,
          title: Container(
            width: 140, // Give it a generous, fixed width
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Image.asset(
              'assets/images/app_logo6.png',
              fit: BoxFit.cover,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CustomPageRoute(child: AuthScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue.shade900,
                    side: BorderSide(color: Colors.blue.shade900, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    'Log In',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

            // Spacer for Transparent AppBar (Toolbar Height + Extra)
            // const SizedBox(height: kToolbarHeight + 8), // Removed from here, handled in RefreshIndicator
            LiquidPullToRefresh(
              color: const Color(0xFFFFF8E1), // Loader color (Gold/Cream)
              backgroundColor: Colors.blue.shade900, // Background color (Blue)
              height: 200,
              showChildOpacityTransition: false,
              animSpeedFactor: 2.0,
              onRefresh: () async {
                await Provider.of<ContentProvider>(
                  context,
                  listen: false,
                ).refreshContent();
              },
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(), // Ensure scroll for refresh
                child: Column(
                  children: [
                    const SizedBox(
                      height: kToolbarHeight + 8,
                    ), // Added back here
                    SizedBox(
                      height: 160,
                      child: _buildTopImagesHeader(),
                    ), // Reduced height container
                    const SizedBox(height: 6),

                    _buildAnnouncementMarquee(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                      ), // Reduced horizontal padding
                      child: Column(
                        children: [
                          const SizedBox(height: 5),
                          Text(
                            'Welcome',
                            style: GoogleFonts.poppins(
                              fontSize: 24, // Reduced font size slightly
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 10), // Reduced spacing
                          // --- 3. LATEST UPDATES SECTION (Horizontal Scroll) ---
                          _buildLatestUpdatesSection(context),

                          const SizedBox(height: 10), // Reduced spacing
                          // --- 4. RECENT PROGRAMS SECTION (Dynamic from Events) ---
                          _buildRecentProgramsSection(context),

                          const SizedBox(height: 25),

                          // Logo Section
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/suvara logo wbg6.png',
                                height: 60, // Reduced logo size
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                          const SizedBox(height: 100), // Padding for bottom nav
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- STICKY BOTTOM FOOTER (Liquid Glass Effect) ---
            Positioned(
              bottom: 16,
              left: 30,
              right: 30,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF7).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFFFFE4B5).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // 1. Home Item
                          _buildBottomNavItem(
                            icon: Icons.home_rounded,
                            label: 'Home',
                            isActive: _selectedIndex == 0,
                            onTap: () {
                              setState(() => _selectedIndex = 0);
                            },
                          ),

                          // 2. Resources Item
                          _buildBottomNavItem(
                            icon: Icons.grid_view_rounded,
                            label: 'Resources',
                            isActive: _selectedIndex == 1,
                            onTap: () {
                              setState(() => _selectedIndex = 1);
                              _showResourcesPopup(context);
                            },
                          ),

                          // 3. Programs Item
                          _buildBottomNavItem(
                            icon: Icons.calendar_month_rounded,
                            label: 'Programs',
                            isActive: _selectedIndex == 2,
                            onTap: () {
                              setState(() => _selectedIndex = 2);
                              Navigator.push(
                                context,
                                CustomPageRoute(child: ProgramsScreen()),
                              ).then((_) {
                                setState(() => _selectedIndex = 0);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final activeColor = Colors.blue.shade900;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: isActive
                  ? BoxDecoration(
                      color: activeColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Icon(
                icon,
                color: isActive ? activeColor : Colors.grey.shade500,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? activeColor : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (previous helper methods)

  // --- Helper Widget for the Announcement Marquee ---
  Widget _buildAnnouncementMarquee() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .doc('global_message')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox(height: 0);
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final announcementText =
            data?['text'] ?? 'Welcome to the Sunday School App!';
        return Container(
          height: 24,
          color: Colors.red.withOpacity(0.1),
          child: Marquee(
            text: announcementText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            blankSpace: 20.0,
            velocity: 50.0,
          ),
        );
      },
    );
  }

  // --- NEW: LATEST UPDATES SECTION ---
  Widget _buildLatestUpdatesSection(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Padding(
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Latest Updates',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        CustomPageRoute(child: BroadcastScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.blue.shade900,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Content
            if (provider.isLoadingBroadcasts && provider.broadcasts.isEmpty)
              SizedBox(
                height: 180,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (_, __) => Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              )
            else if (provider.broadcasts.isEmpty)
              Text(
                'No updates available.',
                style: GoogleFonts.poppins(color: Colors.grey),
              )
            else
              CarouselSlider.builder(
                itemCount: provider.broadcasts.length,
                options: CarouselOptions(
                  height: 110,
                  autoPlay: true,
                  viewportFraction: 0.9,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: true,
                  autoPlayInterval: const Duration(seconds: 4),
                ),
                itemBuilder: (context, index, realIndex) {
                  final data =
                      provider.broadcasts[index].data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Update';
                  final timestamp =
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final imageUrl = data['imageUrl'] as String?;
                  final body = data['body'] ?? '';

                  final iconData = _getIconData(title);

                  final message = BroadcastMessage(
                    title: title,
                    body: body,
                    timestamp: timestamp,
                    imageUrl: imageUrl,
                  );

                  return Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.symmetric(horizontal: 5.0),
                    child: _buildUpdateCard(
                      context: context,
                      title: title,
                      date: DateFormat('MMM d, yyyy').format(timestamp),
                      iconData: iconData,
                      imageUrl: imageUrl,
                      onTap: () => showBroadcastDetailDialog(context, message),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildUpdateCard({
    required BuildContext context,
    required String title,
    required String date,
    required Map<String, dynamic> iconData,
    String? imageUrl,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFE4B5).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: imageUrl == null
                      ? (iconData['gradient'] as LinearGradient?)
                      : null,
                  color: imageUrl == null ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl == null
                    ? Icon(
                        iconData['icon'] as IconData?,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentProgramsSection(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Programs',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        CustomPageRoute(child: HomeEventsScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Colors.blue.shade900,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (provider.isLoadingEvents && provider.events.isEmpty)
              SizedBox(
                height: 160,
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (_, __) => Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              )
            else if (provider.events.isEmpty)
              SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    'No recent programs',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
              )
            else
              CarouselSlider.builder(
                itemCount: provider.events.length,
                options: CarouselOptions(
                  height: 140, // Reduced from 160
                  viewportFraction: 0.5,
                  enlargeCenterPage: true, // Enable enlargement for focus
                  enableInfiniteScroll: true, // Allow looping
                  initialPage: 0,
                  autoPlay: true, // Start moving
                  autoPlayInterval: const Duration(
                    seconds: 5,
                  ), // Slightly slower than Updates
                  padEnds: false,
                  disableCenter: false, // Enable center
                ),
                itemBuilder: (context, index, realIndex) {
                  final doc = provider.events[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'];

                  return GestureDetector(
                    onTap: () {
                      // Navigate to Detail Screen
                      Navigator.push(
                        context,
                        CustomPageRoute(
                          child: EventDetailScreenFromHome(eventId: doc.id),
                        ),
                      );
                    },
                    child: _buildProgramCard(imageUrl),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildProgramCard(String? imageUrl) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.5), // Glassmorphism
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15), // Blue Shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              )
            : const Center(
                child: Icon(Icons.image_not_supported, color: Colors.grey),
              ),
      ),
    );
  }

  // Helper to determine icon style based on title (Matched with BroadcastScreen logic)
  Map<String, dynamic> _getIconData(String title) {
    final lowerTitle = title.toLowerCase();

    if (lowerTitle.contains('lifeline')) {
      return {
        'icon': Icons.favorite_rounded,
        'color': Colors.red.shade400,
        'gradient': LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        ),
      };
    } else if (lowerTitle.contains('kalolsavam')) {
      return {
        'icon': Icons.celebration_rounded,
        'color': Colors.purple.shade400,
        'gradient': LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
        ),
      };
    } else if (lowerTitle.contains('rally')) {
      return {
        'icon': Icons.groups_rounded,
        'color': Colors.orange.shade400,
        'gradient': LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
      };
    } else if (lowerTitle.contains('meeting')) {
      return {
        'icon': Icons.event_rounded,
        'color': Colors.teal.shade400,
        'gradient': LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
      };
    } else if (lowerTitle.contains('important') ||
        lowerTitle.contains('urgent')) {
      return {
        'icon': Icons.priority_high_rounded,
        'color': Colors.red.shade400,
        'gradient': LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        ),
      };
    }

    return {
      'icon': Icons.campaign_rounded,
      'color': Colors.blue.shade400,
      'gradient': LinearGradient(
        colors: [Colors.blue.shade400, Colors.blue.shade600],
      ),
    };
  }

  // --- ANIMATED RESOURCES POPUP ---
  void _showResourcesPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54, // Dim background
      transitionDuration: const Duration(
        milliseconds: 500,
      ), // Gentler, slower animation
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Gentler curved animation
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic, // Gentler than easeOutBack
          reverseCurve: Curves.easeInCubic,
        );

        return Stack(
          children: [
            Positioned(
              bottom:
                  100, // Position ABOVE the floating menu bar (approx 80-90px height)
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: curvedAnimation,
                  alignment: Alignment.bottomCenter, // Scale from bottom center
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 10,
                          sigmaY: 10,
                        ), // Glass effect
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(
                              0xFFFFF4D6,
                            ).withOpacity(0.75), // More visible warm gold glass
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Color(
                                0xFFFFD700,
                              ).withOpacity(0.4), // Stronger gold border
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(
                                  0.2,
                                ), // Stronger warm shadow
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Resources',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // 2x2 Grid Layout for uniformity
                              GridView.count(
                                crossAxisCount: 2, // 2 columns
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 20,
                                crossAxisSpacing: 20,
                                childAspectRatio: 1.0, // Square items
                                children: [
                                  _buildAnimatedMenuItem(
                                    context,
                                    'Catechism',
                                    Icons.auto_stories_rounded,
                                    Colors.purple,
                                    () => Navigator.push(
                                      context,
                                      CustomPageRoute(
                                        child: const CatechismScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAnimatedMenuItem(
                                    context,
                                    'Bible',
                                    Icons.menu_book_rounded,
                                    Colors.orange,
                                    () => Navigator.push(
                                      context,
                                      CustomPageRoute(
                                        child: const PocBibleScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAnimatedMenuItem(
                                    context,
                                    'Japamala',
                                    Icons.volunteer_activism_rounded,
                                    Colors.pink,
                                    () => Navigator.push(
                                      context,
                                      CustomPageRoute(
                                        child: const JapamalaScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAnimatedMenuItem(
                                    context,
                                    'Yamaprarthana',
                                    FontAwesomeIcons.bookOpen,
                                    const Color(0xFF3A5B9A),
                                    () => openYamaprarthanakalApp(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      // Reset to Home when popup is dismissed
      setState(() => _selectedIndex = 0);
    });
  }

  Widget _buildAnimatedMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Close dialog first
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomPageRoute extends PageRouteBuilder {
  final Widget child;

  CustomPageRoute({required this.child})
    : super(
        transitionDuration: const Duration(
          milliseconds: 350,
        ), // Slightly longer for elegance
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Modern Zoom + Fade Transition (Material 3 style)
          const curve = Curves.easeOutQuart;

          var scaleAnimation = Tween<double>(
            begin: 0.92, // Subtle scale up from 92%
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        },
      );
}
