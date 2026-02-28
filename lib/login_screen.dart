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
import 'package:sundayschool_app/homescreen.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCarouselItem(
              'assets/images/marjosepulickal2.png',
              '',
              isAsset: true,
            ),
          ),
          const SizedBox(width: 12),
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
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        color: const Color(0xFFFFFBEB).withOpacity(0.9), // Amber/Gold
        border: Border.all(
          color: const Color(0xFFFDE68A).withOpacity(0.6), // Saturated gold
          width: 1.5,
        ),
        // Shadow removed for performance
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: isAsset
              ? Image.asset(
                  imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  // Cache width to prevent high-res image decoding lag
                  cacheWidth: 800,
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 70,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Image.asset(
              'assets/images/diocese-logo-new1.png',
              height: 50,
              fit: BoxFit.contain,
            ),
          ),
          leadingWidth: 70,
          title: Image.asset(
            'assets/images/app_logo6.png',
            height: 60,
            fit: BoxFit.contain,
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        CustomPageRoute(child: AuthScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF1E3A8A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Log In',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Premium Soft Gold Gradient Background Layer
            RepaintBoundary(
              child: Stack(
                children: [
                  Container(color: const Color(0xFFFFFDF5)), // Warm cream base
                  Positioned(
                    top: -100,
                    right: -100,
                    child: _buildOptimizedBlob(
                      color: const Color(0xFFFFDAB9), // Soft Orange
                      size: 400,
                    ),
                  ),
                  Positioned(
                    bottom: -150,
                    left: -50,
                    child: _buildOptimizedBlob(
                      color: const Color(0xFFFFE5B4), // Peach
                      size: 500,
                    ),
                  ),
                  Positioned(
                    top: 200,
                    left: -100,
                    child: _buildOptimizedBlob(
                      color: const Color(0xFFFFF8DC), // Pale Gold
                      size: 350,
                    ),
                  ),
                ],
              ),
            ),

            // Spacer for Transparent AppBar (Toolbar Height + Extra)
            // const SizedBox(height: kToolbarHeight + 8), // Removed from here, handled in RefreshIndicator
            LiquidPullToRefresh(
              color: const Color(0xFFE2E8F0),
              backgroundColor: const Color(0xFF1E3A8A),
              height: 150,
              showChildOpacityTransition: false,
              animSpeedFactor: 2.0,
              onRefresh: () async {
                await Provider.of<ContentProvider>(
                  context,
                  listen: false,
                ).refreshContent();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: kToolbarHeight + 20),
                    // Animated Header Section
                    TweenAnimationBuilder<double>(
                      duration: const Duration(seconds: 1),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Column(
                        children: [
                          _buildTopImagesHeader(),
                          const SizedBox(height: 12),
                          _buildAnnouncementMarquee(),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Eparchy of Kanjirapally',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          _buildLatestUpdatesSection(context),
                          const SizedBox(height: 24),
                          _buildRecentProgramsSection(context),
                          const SizedBox(height: 48),
                          // Premium Logo Footer
                          Column(
                            children: [
                              Image.asset(
                                'assets/images/suvara logo wbg6.png',
                                height: 70,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '© ${DateTime.now().year} AJCE. All Rights Reserved.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(
                                    0xFF1E3A8A,
                                  ).withOpacity(0.4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 120),
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
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFFFBEB,
                      ).withOpacity(0.85), // Soft Gold
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(
                          0xFFFDE68A,
                        ).withOpacity(0.6), // Saturated Gold
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBottomNavItem(
                            icon: Icons.home_rounded,
                            label: 'Home',
                            isActive: _selectedIndex == 0,
                            onTap: () {
                              setState(() => _selectedIndex = 0);
                            },
                          ),
                          _buildBottomNavItem(
                            icon: Icons.grid_view_rounded,
                            label: 'Resources',
                            isActive: _selectedIndex == 1,
                            onTap: () {
                              setState(() => _selectedIndex = 1);
                              _showResourcesPopup(context);
                            },
                          ),
                          _buildBottomNavItem(
                            icon: Icons.calendar_month_rounded,
                            label: 'Programs',
                            isActive: _selectedIndex == 2,
                            onTap: () {
                              setState(() => _selectedIndex = 2);
                              Navigator.push(
                                context,
                                CustomPageRoute(child: const ProgramsScreen()),
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

  Widget _buildOptimizedBlob({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.4),
            color.withOpacity(0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
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
    final activeColor = const Color(0xFF1E3A8A);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : const Color(0xFF64748B),
              size: 20,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
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
          height: 28,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            border: Border.symmetric(
              horizontal: BorderSide(color: Colors.red.withOpacity(0.1)),
            ),
          ),
          child: Marquee(
            text: announcementText,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.red.shade700,
            ),
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            blankSpace: 20.0,
            velocity: 40.0,
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
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
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
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: const Color(0xFF1E3A8A),
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
                    id: provider.broadcasts[index].id,
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
                      heroTag: imageUrl != null
                          ? 'broadcast_image_${provider.broadcasts[index].id}'
                          : 'broadcast_icon_${provider.broadcasts[index].id}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BroadcastDetailScreen(message: message),
                          ),
                        );
                      },
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
    String? heroTag,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB).withOpacity(0.9), // Soft Gold
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFDE68A).withOpacity(0.6), // Saturated gold
            width: 1.5,
          ),
          // Shadow removed for scroll performance
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              if (heroTag != null)
                Hero(
                  tag: heroTag,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: imageUrl == null
                          ? (iconData['gradient'] as LinearGradient?)
                          : null,
                      color: imageUrl == null ? null : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (iconData['color'] as Color? ?? Colors.blue)
                              .withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                            )
                          : Center(
                              child: Icon(
                                iconData['icon'] as IconData?,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: imageUrl == null
                        ? (iconData['gradient'] as LinearGradient?)
                        : null,
                    color: imageUrl == null ? null : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (iconData['color'] as Color? ?? Colors.blue)
                            .withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                          )
                        : Center(
                            child: Icon(
                              iconData['icon'] as IconData?,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: const Color(0xFF1E3A8A),
                ),
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
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
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
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: const Color(0xFF1E3A8A),
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
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
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
                    child: _buildProgramCard(imageUrl, data['category'] ?? ''),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildProgramCard(String? imageUrl, String category) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFFFFBEB).withOpacity(0.9), // Soft Gold
        border: Border.all(
          color: const Color(0xFFFDE68A).withOpacity(0.6), // Saturated gold
          width: 1.5,
        ),
        gradient: imageUrl == null || imageUrl.isEmpty
            ? HomeScreen.getEventPlaceholderData(category)['gradient']
                  as LinearGradient?
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient:
                        HomeScreen.getEventPlaceholderData(category)['gradient']
                            as LinearGradient?,
                  ),
                  child: Center(
                    child: Icon(
                      HomeScreen.getEventPlaceholderData(category)['icon']
                          as IconData?,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              )
            : Center(
                child: Icon(
                  HomeScreen.getEventPlaceholderData(category)['icon']
                      as IconData?,
                  color: Colors.white,
                  size: 40,
                ),
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
              left: 40,
              right: 40,
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
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFFBEB,
                            ).withOpacity(0.85), // Soft Gold
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: const Color(
                                0xFFFDE68A,
                              ).withOpacity(0.6), // Saturated gold
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF1E3A8A,
                                ).withOpacity(0.15),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
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
                              Text(
                                'Resources',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E3A8A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.1,
                                children: [
                                  _buildAnimatedMenuItem(
                                    context,
                                    'Catechism',
                                    Icons.auto_stories_rounded,
                                    const Color(0xFF6366F1),
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
                                    const Color(0xFFF59E0B),
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
                                    const Color(0xFFEC4899),
                                    () => Navigator.push(
                                      context,
                                      CustomPageRoute(
                                        child: const JapamalaScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildAnimatedMenuItem(
                                    context,
                                    'Prayers',
                                    FontAwesomeIcons.handsPraying,
                                    const Color(0xFF0EA5E9),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
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
