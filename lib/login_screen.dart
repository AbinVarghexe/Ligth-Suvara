// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:marquee/marquee.dart';
import 'package:sundayschool_app/auth_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Assuming you have all these screen imports available
import 'package:sundayschool_app/broadcast_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sundayschool_app/catechism_screen.dart';
// Note: This import was missing in your provided code but is used in the carousel.
// Ensure this file exists and is correct.
import 'package:sundayschool_app/event_detail_screen_from_home.dart';
import 'package:sundayschool_app/bible.dart';
import 'package:sundayschool_app/japamala.dart';
import 'package:sundayschool_app/home_events.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // --- 1. NEW METHOD TO SHOW THE BOTTOM SHEET ---
  // lib/login_screen.dart

  void _showMenuBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              // Menu Title
              Text(
                'Menu',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),

              // --- MENU BUTTONS (with alignment fix) ---

              _buildMenuListItem(
                context: context,
                title: 'POC BIBLE',
                // FIX 1: Wrap Icon in a SizedBox for consistent width
                leading: SizedBox(
                  width: 32, // Consistent width
                  child: Icon(Icons.book_outlined, color: Colors.blue.shade900, size: 28),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PocBibleScreen()),
                  );
                },
              ),

              _buildMenuListItem(
                context: context,
                title: 'JAPAMALA',
                // FIX 2: Adjust SizedBox to match the consistent width
                leading: SizedBox(
                  width: 32, // Consistent width
                  height: 32,
                  child: Image.asset(
                    'assets/images/rosary.png',
                    color: Colors.blue.shade900,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const JapamalaScreen()),
                  );
                },
              ),

              _buildMenuListItem(
                context: context,
                title: 'CATECHISM STUDY MATERIALS',
                // FIX 3: Wrap Icon in a SizedBox for consistent width
                leading: SizedBox(
                  width: 32, // Consistent width
                  child: Icon(Icons.school_outlined, color: Colors.blue.shade900, size: 28),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CatechismScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Helper widget to build styled list tiles for the menu
  Widget _buildMenuListItem({
    required BuildContext context,
    required String title,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.blue.shade900,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 60, // Retained large height
          title: Container(
            width: 140, // Give it a generous, fixed width
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Image.asset(
              'assets/images/app_logo4.jpg',
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
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
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
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(), // Allow scrolling only when needed
              child: Column(
                children: [
                  const SizedBox(height: 8), // Space between AppBar and carousel
                  SizedBox(height: 260, child: _buildEventsCarousel()),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeEventsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View all events',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  _buildAnnouncementMarquee(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          'Welcome',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BroadcastScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.new_releases_outlined),
                            label: Text(
                              'View Recent Updates',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blue.shade900,
                              side: BorderSide(
                                color: Colors.blue[900]!,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showMenuBottomSheet(context);
                            },
                            icon: const Icon(Icons.menu_book_outlined),
                            label: Text(
                              'Menu',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blue.shade900,
                              side: BorderSide(
                                color: Colors.blue[900]!,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 5),
                            Image.asset(
                              'assets/images/suvara logo wbg5.jpg',
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                            Image.asset(
                              'assets/images/diocese-logo-new1.png',
                              height: 55,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const SizedBox(height: 60), // Space for the footer
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Text(
                '© ${DateTime.now().year} AJCE. All Rights Reserved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.blue.shade900.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget for the Events Carousel ---
  Widget _buildEventsCarousel() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
      // CORE CHANGE: Filter by isPublic == true to only show admin-approved events
          .where('isPublic', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: CarouselSlider.builder(
              itemCount: 3,
              itemBuilder: (context, index, realIndex) {
                return Container(
                  margin: const EdgeInsets.all(5.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                );
              },
              options: CarouselOptions(
                height: 260,
                enlargeCenterPage: true,
                viewportFraction: 0.8,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Show two fixed asset slides when there are no events
          final fixedAssets = [
            'assets/images/unnamed2.png',
            'assets/images/marjosepulickal2.png',
          ];
          return CarouselSlider.builder(
            itemCount: fixedAssets.length,
            itemBuilder: (context, index, realIndex) {
              return _buildCarouselItem(
                fixedAssets[index],
                '',
                isAsset: true,
              );
            },
            options: CarouselOptions(
              height: 260,
              autoPlay: true,
              enlargeCenterPage: true,
              viewportFraction: 0.8,
            ),
          );
        }
        final eventDocs = snapshot.data!.docs;
        final int dynamicCount = eventDocs.length;
        final int totalCount = dynamicCount + 2; // +2 for the fixed asset slides
        return CarouselSlider.builder(
          itemCount: totalCount,
          itemBuilder: (context, index, realIndex) {
            if (index == 0 || index == 1) {
              // Two fixed slides from assets
              final fixed = index == 0
                  ? 'assets/images/marjosepulickal2.png'
                  : 'assets/images/unnamed2.png';
              final fixedTitle = '';
              return _buildCarouselItem(fixed, fixedTitle, isAsset: true);
            } else {
              final event = eventDocs[index - 2];
              String imageUrl = event['imageUrl'] ?? 'https://via.placeholder.com/1000';
              String title = event['title'] ?? 'Event Title';
              String place = event['place']?.toString() ?? '';
              String eventId = event.id;

              return GestureDetector(
                onTap: () {
                  // Navigate to the event detail screen
                },
                child: _buildCarouselItem(imageUrl, title, subtitle: place),
              );
            }
          },
          options: CarouselOptions(
            height: 260,
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: 0.8,
          ),
        );
      },
    );
  }

  // Updated _buildCarouselItem to use a darker overlay
  Widget _buildCarouselItem(String imageUrl, String title, {bool isAsset = false, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.all(5.0),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(15.0)),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (isAsset)
              Image.asset(
                imageUrl,
                fit: BoxFit.contain, // show full asset without cropping
                alignment: Alignment.center,
              )
            else
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image, color: Colors.grey[400]),
                ),
              ),
            if ((title.trim().isNotEmpty) || (subtitle != null && subtitle.trim().isNotEmpty))
              Positioned(
                bottom: 0.0,
                left: 0.0,
                right: 0.0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 0, 0, 0), // Solid black at the bottom
                        Color.fromARGB(0, 0, 0, 0),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.trim().isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget for the Announcement Marquee ---
  Widget _buildAnnouncementMarquee() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .doc('global_message') // Corrected to global_message
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox(height: 0); // Hide if no announcement
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final announcementText =
            data?['text'] ?? 'Welcome to the Sunday School App!';
        return Container(
          height: 24,
          color: Colors.red.withAlpha(26), // Using withAlpha for modern syntax
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
}
