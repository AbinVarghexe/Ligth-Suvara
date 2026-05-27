// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui'; // Required for ImageFilter
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:marquee/marquee.dart';
import 'package:sundayschool_app/utils/app_launcher.dart'; // Restored for Yamaprarthanakal
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Restored for icons
import 'package:sundayschool_app/auth_screen.dart'; // Added AuthScreen import
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/public_registration_screen.dart';
import 'package:sundayschool_app/widgets/cinematic_message_view.dart';

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
import 'package:sundayschool_app/video_resources_guide_screen.dart';
import 'package:sundayschool_app/video_resources_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sundayschool_app/widgets/heavenly_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  AnimationController?
  _bgAnimationController; // Nullable to avoid LateInitializationError on hot reload
  int _selectedIndex = 0; // 0: Home, 1: Resources, 2: Programs
  int _currentRegIndex = 0; // Track current registration program index
  Stream<QuerySnapshot>? _publicProgramsStream;
  Timer? _bannerTimer; // 🔹 Timer for 3-second auto-play
  final Map<String, Uint8List> _base64Cache = {};

  Widget _buildVerseSection(Map<String, dynamic> config) {
    if (config.isEmpty || config['verseText'] == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300.withValues(alpha: 0.5),
        highlightColor: Colors.white.withValues(alpha: 0.6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      );
    }

    final verseText = config['verseText'];
    final verseRef = config['verseRef'] ?? '';
    final verseBgImage = config['verseBgImage'];
    final titleBgColor = _getVerseTitleBgColor(config);
    final verseTextColor = _getVerseTextColor(config);
    final hasImage = verseBgImage != null && verseBgImage.isNotEmpty;

    // 🔹 Visibility focus flags from DB
    final hideText = config['hideVerseText'] ?? false;
    // 🔹 Automatically give full clarity ONLY if text is hidden
    final fullClarity = hideText;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 4),
      constraints: const BoxConstraints(minHeight: 160),
      width: double.infinity,
      child: GlowingRunningBorder(
        borderRadius: 32,
        thickness: hasImage ? 6.0 : 2.5, // Significantly thicker for visibility
        duration: Duration(seconds: hasImage ? 3 : 10), // Much faster/dynamic
        gradientColors: hasImage
            ? [
                Colors.yellow.shade300,
                Colors.orange.shade600,
                Colors.white, // Pure white core for maximum shine
                const Color(0xFFBC8A3A), // Gold
                Colors.white,
                Colors.orange.shade500,
                Colors.yellow.shade300,
              ]
            : const [Color(0xFFBC8A3A), Color(0xFFFFD700), Color(0xFFBC8A3A)],
        child: Container(
          decoration: BoxDecoration(
            color: hasImage
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: (hasImage && !fullClarity)
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                Positioned.fill(
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: verseBgImage!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) =>
                              Container(color: Colors.grey.shade200),
                        )
                      : BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.2),
                                  Colors.blue.shade100.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                ),
                // 🔹 Content Overlay
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10, // Aggressively reduced from 18
                  ),
                  decoration: BoxDecoration(
                    gradient: (hasImage && !fullClarity)
                        ? RadialGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.2), // Light core
                              Colors.black.withValues(
                                alpha: 0.65,
                              ), // Strong edge vignette
                            ],
                            radius: 1.2,
                          )
                        : null,
                    color: (hasImage && !fullClarity)
                        ? null
                        : Colors.transparent,
                  ),
                  child: hideText
                      ? const SizedBox(
                          height: 160,
                          width: double.infinity,
                        ) // 🔹 Fixed anchor height when text is hidden
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🔹 Database-Driven Title with Background Logic
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (titleBgColor == Colors.transparent &&
                                        !hasImage)
                                    ? const Color(
                                        0xFFBC8A3A,
                                      ).withValues(alpha: 0.85)
                                    : titleBgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                (config['verseTitle'] ?? 'Verse of the Day')
                                    .toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12), // Reduced from 16
                            // 🔹 Serif Verse Text
                            Text(
                              '"$verseText"',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.libreBaskerville(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight
                                    .w600, // Slightly bolder for legibility
                                color:
                                    verseTextColor, // Restoration: Using database-selected color
                                height: 1.5,
                                shadows: hasImage
                                    ? [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.8,
                                          ),
                                          offset: const Offset(0, 1.5),
                                          blurRadius: 6,
                                        ),
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          offset: const Offset(0, 0),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12), // Reduced from 16
                            // 🔹 Glassmorphic Verse Reference
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (hasImage ? Colors.black : Colors.white)
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          (hasImage
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.1),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    verseRef.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: hasImage
                                          ? Colors.white
                                          : const Color(0xFFBC8A3A),
                                      letterSpacing: 1.2,
                                      shadows: hasImage
                                          ? [
                                              Shadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                offset: const Offset(0, 1),
                                                blurRadius: 3,
                                              ),
                                            ]
                                          : null,
                                    ),
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
      ),
    );
  }

  Widget _buildTopImagesHeader(Map<String, dynamic> config) {
    if (config.isEmpty || config['carousel'] == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300.withValues(alpha: 0.5),
        highlightColor: Colors.white.withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 144, // Matches 160 - 16 padding
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ),
      );
    }

    final List<dynamic> remoteSlides = config['carousel'];
    if (remoteSlides.isEmpty) return const SizedBox.shrink();

    return CarouselSlider.builder(
      itemCount: remoteSlides.length,
      options: CarouselOptions(
        height: 160, // Match Verse height
        autoPlay: true,
        enlargeCenterPage: false, // Prevent size variations
        viewportFraction: 1.0, // Full width match
        autoPlayInterval: const Duration(seconds: 6),
        autoPlayCurve: Curves.easeInOutCubic,
        autoPlayAnimationDuration: const Duration(milliseconds: 1000),
      ),
      itemBuilder: (context, index, realIndex) {
        final slide = remoteSlides[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildCarouselItem(
            context,
            slide['label'] ?? '',
            slide['name'] ?? '',
            slide['role'] ?? '',
            slide['message'] ?? '',
            slide['image'] ?? '',
          ),
        );
      },
    );
  }

  Widget _buildCarouselItem(
    BuildContext context,
    String label,
    String name,
    String role,
    String message,
    String imageUrl,
  ) {
    // 🔹 Ensure "the" is present in labels like "Message from the Director"
    final displayLabel =
        label.toLowerCase().contains("from") &&
            !label.toLowerCase().contains("from the")
        ? label.replaceFirst("from", "from the")
        : label;

    // 🔹 Fix missing spaces after REV. and DR. from the database
    String displayName = name.toUpperCase();
    if (displayName.contains("REV.") && !displayName.contains("REV. ")) {
      displayName = displayName.replaceFirst("REV.", "REV. ");
    }
    if (displayName.contains("DR.") && !displayName.contains("DR. ")) {
      displayName = displayName.replaceFirst("DR.", "DR. ");
    }

    return InkWell(
      onTap: () => _showMessageDetail(context, name, role, message, imageUrl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Row(
            children: [
              // 🔹 Text side - Left
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    16,
                    8,
                    16,
                  ), // Less right padding to give more room
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFBC8A3A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayName,
                          maxLines: 1,
                          softWrap: false,
                          style: GoogleFonts.outfit(
                            fontSize:
                                13.5, // Slightly larger base, will auto-scale down
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E3A8A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBC8A3A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Read Message',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 🔹 Image side - Right (Narrower width to give text more space)
              SizedBox(
                width:
                    115, // Reduced from 130 to give text area approx 15px more room
                height: double.infinity,
                child: imageUrl.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade200,
                          highlightColor: Colors.grey.shade100,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.grey,
                            size: 28,
                          ),
                        ),
                      )
                    : Image.asset(
                        imageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageDetail(
    BuildContext context,
    String name,
    String role,
    String message,
    String imageUrl,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CinematicMessageView(
          name: name,
          role: role,
          message: message,
          imageUrl: imageUrl,
        ),
      ),
    );
  }

  Color _getVerseTextColor(Map<String, dynamic> config) {
    String? colorStr = config['verseTextColor'];
    String? verseBgImage = config['verseBgImage'];
    switch (colorStr) {
      case 'black':
        return Colors.black;
      case 'gold':
        return const Color(0xFFBC8A3A);
      case 'blue':
        return const Color(0xFF1E3A8A);
      case 'white':
        return Colors.white;
      default:
        return (verseBgImage != null && verseBgImage.isNotEmpty)
            ? Colors.white
            : const Color(0xFF1E3A8A);
    }
  }

  Color _getVerseTitleBgColor(Map<String, dynamic> config) {
    String? colorStr = config['verseTitleBgColor'];
    switch (colorStr) {
      case 'white':
        return Colors.white.withValues(alpha: 0.9);
      case 'black':
        return Colors.black.withValues(alpha: 0.7);
      case 'gold':
        return const Color(0xFFBC8A3A).withValues(alpha: 0.9);
      case 'blue':
        return const Color(0xFF1E3A8A).withValues(alpha: 0.9);
      case 'transparent':
      default:
        return Colors.transparent;
    }
  }

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat(reverse: true);

    _publicProgramsStream = FirebaseFirestore.instance
        .collection('public_registration_programs')
        .where('isActive', isEqualTo: true)
        .snapshots();

    // 🔹 Start 3-second cycle for banners
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (isCurrent) {
          setState(() {
            _currentRegIndex++;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bgAnimationController?.dispose();
    super.dispose();
  }

  Widget _buildAnimatedBackground() {
    return const HeavenlyBackground(child: SizedBox.expand());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white, // Fallback color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64, // Reduced from 72 for tighter header

        leading: Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: Image.asset(
            'assets/images/diocese.png',
            height: 55,
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 80,
        title: Hero(
          tag: 'app_logo',
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Soft Golden Glow (Behind)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Image.asset(
                  'assets/images/new_logo_light.png',
                  height: 62, // Slightly larger for the glow
                  color: const Color(
                    0xFFFFD700,
                  ).withValues(alpha: 0.5), // Pure Gold Glow
                  fit: BoxFit.contain,
                ),
              ),
              // 2. Crisp Logo (Front)
              Image.asset(
                'assets/images/new_logo_light.png',
                height: 58,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
        ),

        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 32.0),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      CustomPageRoute(child: AuthScreen()),
                    );
                  },
                  icon: const Icon(
                    Icons.notes_rounded, // 3 lines
                    color: Color(0xFFBC8A3A), // Gold accent
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ✨ Heavenly Animated Background Layer (Repaint-Isolated)
          Positioned.fill(child: _buildAnimatedBackground()),

          // 🛡️ Scroll Optimization Layer
          ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              overscroll: false,
            ), // Disables Android's stretch distortion
            child: LiquidPullToRefresh(
              color: Colors.white.withValues(alpha: 0.2),
              backgroundColor: const Color(0xFF1E3A8A),
              height: 120,
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
                    const BouncingScrollPhysics(), // Smooth premium scrolling
                child: RepaintBoundary(
                  // ✨ Decouples the scrolling list from the complex background animations
                  child: Consumer<ContentProvider>(
                    builder: (context, contentProvider, child) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final bool isShortScreen = screenHeight < 720;
                      final config = contentProvider.loginConfig;

                      return Column(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).padding.top + 25,
                          ),
                          // Animated Header Section
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 1500),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutExpo,
                            builder: (context, value, child) {
                              return ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 20 * (1 - value),
                                  sigmaY: 20 * (1 - value),
                                ),
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: Column(
                                      children: [
                                        _buildVerseSection(config),
                                        SizedBox(height: isShortScreen ? 4 : 6),
                                        _buildTopImagesHeader(config),
                                        SizedBox(height: isShortScreen ? 6 : 8),
                                        _buildAnnouncementMarquee(),
                                        SizedBox(
                                          height: isShortScreen ? 6 : 10,
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              'Welcome',
                                              style: GoogleFonts.outfit(
                                                fontSize: isShortScreen
                                                    ? 28
                                                    : 32,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            Text(
                                              'Diocese of Kanjirapally',
                                              style: GoogleFonts.outfit(
                                                fontSize: isShortScreen
                                                    ? 12.5
                                                    : 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.blue.shade900,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildPublicRegistrationSection(),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Column(
                              children: [
                                _buildLatestUpdatesSection(context),
                                const SizedBox(height: 24),
                                _buildRecentProgramsSection(context),
                                const SizedBox(height: 48),
                                // 🌟 Liquid Glass Brand Block
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 25,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 30,
                                        sigmaY: 30,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.15,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Hero(
                                              tag: 'login_logo_glass',
                                              child: Image.asset(
                                                'assets/images/suvara logo wbg6.png',
                                                height: 52,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              '© ${DateTime.now().year} AJCE. All Rights Reserved.',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                fontSize: 10,
                                                color: const Color(
                                                  0xFF1E3A8A,
                                                ).withValues(alpha: 0.5),
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // --- STICKY BOTTOM FOOTER (Liquid Glass Effect) ---
          Positioned(
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
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
                    ).withValues(alpha: 0.85), // Soft Gold
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(
                        0xFFFDE68A,
                      ).withValues(alpha: 0.6), // Saturated Gold
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
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
                                _showResourcesPopup(context);
                              },
                            ),
                            _buildBottomNavItem(
                              icon: Icons.calendar_month_rounded,
                              label: 'Programs',
                              isActive: _selectedIndex == 2,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CustomPageRoute(
                                    child: const ProgramsScreen(),
                                  ),
                                );
                              },
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
        ],
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final activeColor = const Color(0xFFBC8A3A); // Gold accent
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
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

  // --- NEW: PUBLIC REGISTRATION SECTION ("Perfect" Clutter-Free Gesture version) ---
  Widget _buildPublicRegistrationSection() {
    if (_publicProgramsStream == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _publicProgramsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final now = Timestamp.now();
        final activeRegistrations = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final startDate = data['startDate'] as Timestamp?;
          final endDate = data['endDate'] as Timestamp?;

          // Verify if now is within the registration window
          bool isStarted = startDate == null || startDate.compareTo(now) <= 0;
          bool isNotEnded = endDate == null || endDate.compareTo(now) > 0;

          return isStarted && isNotEnded;
        }).toList();

        if (activeRegistrations.isEmpty) return const SizedBox.shrink();

        // 🛡️ Safe Index Handling (Supports Auto-Cycle)
        final displayIndex = _currentRegIndex % activeRegistrations.length;

        final programDoc = activeRegistrations[displayIndex];
        final programData = programDoc.data() as Map<String, dynamic>;
        final title = programData['name'] ?? 'Program';
        final regInfo = programData['regInfo'] as String?;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (activeRegistrations.length <= 1) return;

              // 🔹 Detect Swipe Direction
              final velocity = details.primaryVelocity ?? 0.0;
              if (velocity < 0) {
                // Swipe Left -> Next
                setState(() {
                  _currentRegIndex =
                      (_currentRegIndex + 1) % activeRegistrations.length;
                });
              } else if (velocity > 0) {
                // Swipe Right -> Previous
                setState(() {
                  _currentRegIndex =
                      (_currentRegIndex - 1 + activeRegistrations.length) %
                      activeRegistrations.length;
                });
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: GlowingRunningBorder(
                key: ValueKey<int>(displayIndex),
                borderRadius: 24,
                thickness: 6.0,
                duration: const Duration(seconds: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E3A8A), // Deep Blue
                        Color(0xFF4338CA), // Indigo
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFBC8A3A).withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBC8A3A).withValues(alpha: 0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: Color(0xFF1E3A8A),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBC8A3A),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'REGISTRATION OPEN',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 58,
                        height: 48,
                        child: _PulsingButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              CustomPageRoute(
                                child: PublicRegistrationScreen(
                                  eventId: programDoc.id,
                                  eventTitle: title,
                                  regInfo: regInfo,
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
        );
      },
    );
  }

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
            color: Colors.red.withValues(alpha: 0.05),
            border: Border.symmetric(
              horizontal: BorderSide(color: Colors.red.withValues(alpha: 0.1)),
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
                      color: const Color(0xFF1E3A8A), // App Blue
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
                            color: const Color(0xFFBC8A3A), // Gold accent
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: const Color(0xFFBC8A3A), // Gold accent
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
                    key: ValueKey('broadcast_carousel_${provider.broadcasts[index].id}'),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(
                0xFFFFFBEB,
              ).withValues(alpha: 0.25), // Transparent Glass Feel
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(
                  0xFFFDE68A,
                ).withValues(alpha: 0.4), // Subtle Gold Border
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // 💎 Elegant Icon/Image Pod
                Hero(
                  tag: heroTag ?? UniqueKey().toString(),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          const Color(
                            0xFFBC8A3A,
                          ).withValues(alpha: 0.9), // Gold
                          const Color(
                            0xFFFDE68A,
                          ).withValues(alpha: 0.7), // Amber
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              key: ValueKey(imageUrl),
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (context, url) =>
                                  Container(color: Colors.white10),
                              errorWidget: (context, url, error) =>
                                  _buildUpdateIcon(iconData, 28),
                            )
                          : _buildUpdateIcon(iconData, 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 📝 Content
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E3A8A), // Deep Royal Blue
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(
                            0xFFBC8A3A,
                          ).withValues(alpha: 0.9), // Muted Gold
                        ),
                      ),
                    ],
                  ),
                ),

                // ➡️ Subtle Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: const Color(0xFFBC8A3A).withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateIcon(Map<String, dynamic> iconData, double size) {
    return Center(
      child: Icon(
        iconData['icon'] as IconData?,
        color: Colors.white,
        size: size,
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
                      color: const Color(0xFF1E3A8A), // App Blue
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
                            color: const Color(0xFFBC8A3A), // Gold accent
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: const Color(0xFFBC8A3A), // Gold accent
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
                    key: ValueKey('event_carousel_${doc.id}'),
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
    final placeholderData = HomeScreen.getEventPlaceholderData(category);
    final placeholder = Center(
      child: Icon(
        placeholderData['icon'] as IconData?,
        color: Colors.white,
        size: 40,
      ),
    );

    Widget imageWidget;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('data:image/')) {
        // Base64 data URL stored by older admin uploads
        try {
          Uint8List bytes;
          if (_base64Cache.containsKey(imageUrl)) {
            bytes = _base64Cache[imageUrl]!;
          } else {
            bytes = base64Decode(imageUrl.split(',').last);
            _base64Cache[imageUrl] = bytes;
          }
          imageWidget = Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            key: ValueKey(imageUrl),
            errorBuilder: (_, __, ___) => placeholder,
          );
        } catch (_) {
          imageWidget = placeholder;
        }
      } else {
        imageWidget = CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          key: ValueKey(imageUrl),
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (context, url) => Container(color: Colors.grey.shade200),
          errorWidget: (context, url, error) => Container(
            decoration: BoxDecoration(
              gradient: placeholderData['gradient'] as LinearGradient?,
            ),
            child: placeholder,
          ),
        );
      }
    } else {
      imageWidget = placeholder;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFFFFFBEB).withValues(alpha: 0.9),
        border: Border.all(
          color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
          width: 1.5,
        ),
        gradient: (imageUrl == null || imageUrl.isEmpty)
            ? placeholderData['gradient'] as LinearGradient?
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: imageWidget,
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
      barrierColor: Colors.black.withValues(alpha: 0.2), // Lightened barrier

      transitionDuration: const Duration(
        milliseconds: 300,
      ), // Faster animation for snappier feel
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Balanced curved animation
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves
              .easeOutCubic, // Changed to easeOut for more apparent start of exit
        );

        // Glide-up on enter, Glide-down on exit
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.15), // Start slightly below
          end: Offset.zero,
        ).animate(curvedAnimation);

        return Stack(
          children: [
            Positioned(
              bottom: 100, // Position ABOVE the floating menu bar
              left: 40,
              right: 40,
              child: PopScope(
                canPop: true,
                onPopInvokedWithResult: (didPop, result) {
                  // The system back button already triggered a pop,
                  // and showGeneralDialog's navigator will handle the animation
                  // if it's not being interrupted.
                },
                child: Material(
                  color: Colors.transparent,
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: ScaleTransition(
                      scale: curvedAnimation,
                      alignment: Alignment.bottomCenter,
                      child: SlideTransition(
                        position: slideAnimation,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: RepaintBoundary(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFFBEB,
                                  ).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFD4AF37,
                                    ).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFBC8A3A,
                                      ).withValues(alpha: 0.12),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: -5,
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
                                        color: const Color(
                                          0xFF1E3A8A,
                                        ), // Navy for contrast on white glass
                                        letterSpacing: -0.5,
                                      ),
                                    ),

                                    const SizedBox(height: 24),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final itemWidth = (constraints.maxWidth - 32) / 3;
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                SizedBox(
                                                  width: itemWidth,
                                                  child: _buildAnimatedMenuItem(
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
                                                ),
                                                SizedBox(
                                                  width: itemWidth,
                                                  child: _buildAnimatedMenuItem(
                                                    context,
                                                    'Bible',
                                                    Icons.menu_book_rounded,
                                                    const Color(0xFFF59E0B),
                                                    () => openBible(context),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: itemWidth,
                                                  child: _buildAnimatedMenuItem(
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
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: itemWidth,
                                                  child: _buildAnimatedMenuItem(
                                                    context,
                                                    'Yama\nPrarthanakal',
                                                    FontAwesomeIcons.handsPraying,
                                                    const Color(0xFF0EA5E9),
                                                    () =>
                                                        openYamaprarthanakalApp(context),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                SizedBox(
                                                  width: itemWidth,
                                                  child: _buildAnimatedMenuItem(
                                                    context,
                                                    'Videos',
                                                    Icons.play_circle_fill_rounded,
                                                    const Color(0xFFEF4444),
                                                    () => Navigator.push(
                                                      context,
                                                      CustomPageRoute(
                                                        child: const VideoResourcesScreen(),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
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
        // Subtle delay so the exit animation is visible before navigation
        Future.delayed(const Duration(milliseconds: 150), () {
          onTap();
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A8A),
                height: 1.1,
              ),
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
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = Curves.easeOutBack;

          // 1. Smooth Fade
          var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
            ),
          );

          // 2. Liquid Scale
          var scaleAnimation = Tween<double>(
            begin: 0.92,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          // 3. Subtle Vertical Glide
          var slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.08), // Small glide up
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          return Stack(
            children: [
              // White backing to prevent seeing Navigator's black background during scaling
              Container(color: Colors.white),
              FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    alignment: Alignment.center,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class GlowingRunningBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final List<Color> gradientColors;
  final double thickness;
  final Duration duration;

  const GlowingRunningBorder({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.thickness = 4.0,
    this.duration = const Duration(seconds: 4),
    this.gradientColors = const [
      Color(0xFFBC8A3A), // Gold
      Color(0xFFFFD700), // Gold Lighter
      Color(0xFFBC8A3A),
    ],
  });

  @override
  State<GlowingRunningBorder> createState() => _GlowingRunningBorderState();
}

class _GlowingRunningBorderState extends State<GlowingRunningBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GlowBorderPainter(
            animationValue: _controller.value,
            borderRadius: widget.borderRadius,
            gradientColors: widget.gradientColors,
            thickness: widget.thickness,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

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
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Cinematic Gradient-Animated Shadow Glow (Gold -> Orange -> White)
    // We cycle through intermediate colors based on animationValue
    final Color glowColor = _getGlowColor(animationValue);

    // --- OPTIMIZED HALO: REDUCED SPREAD TO PREVENT RENDERING ARTIFACTS ---
    final haloPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          thickness *
          4.0 // Reduced from 20.0 to prevent bleed
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        thickness * 2.5,
      ); // Reduced from 12.0
    canvas.drawRRect(rRect, haloPaint);

    final staticGlowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          thickness *
          1.5 // Refined core glow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 1.2);
    canvas.drawRRect(rRect, staticGlowPaint);

    // 2. Shimmer Waves Effect
    // If we have an RGB spectrum (many colors), use the whole list.
    // Otherwise, use the high-contrast "shimmer" structure.
    final List<Color> shimmerColors;
    final List<double>? shimmerStops;

    if (gradientColors.length > 3) {
      // RGB Mode: Use the full spectrum
      shimmerColors = gradientColors;
      shimmerStops = null;
    } else {
      // Classic Mode: Two-tone shimmer with white peaks
      shimmerColors = [
        Colors.transparent,
        gradientColors.first.withValues(alpha: 0.3),
        gradientColors.length > 1 ? gradientColors[1] : gradientColors.first,
        Colors.white,
        gradientColors.length > 1 ? gradientColors[1] : gradientColors.first,
        Colors.transparent,
        (gradientColors.length > 1 ? gradientColors[1] : gradientColors.first)
            .withValues(alpha: 0.5),
        Colors.white.withValues(alpha: 0.8),
        (gradientColors.length > 1 ? gradientColors[1] : gradientColors.first)
            .withValues(alpha: 0.5),
        Colors.transparent,
      ];
      shimmerStops = const [
        0.0,
        0.4,
        0.45,
        0.5,
        0.55,
        0.6,
        0.75,
        0.8,
        0.85,
        1.0,
      ];
    }

    final waveValue = math.sin(animationValue * 2 * math.pi);
    final shimmerPaint = Paint()
      ..shader = SweepGradient(
        colors: shimmerColors,
        stops: shimmerStops,
        transform: GradientRotation(
          animationValue * 2 * math.pi + waveValue * 0.2,
        ),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rRect, shimmerPaint);
  }

  Color _getGlowColor(double t) {
    if (gradientColors.length > 3) {
      // Cycle through RGB for Halo if in RGB mode
      final double progress = t * (gradientColors.length - 1);
      final int index = progress.floor();
      final double nextT = progress - index;
      return Color.lerp(
        gradientColors[index],
        gradientColors[(index + 1) % gradientColors.length],
        nextT,
      )!;
    }

    // Classic: Gold -> Warm Orange -> Soft White -> Gold
    if (t < 0.33) {
      return Color.lerp(
        const Color(0xFFBC8A3A),
        const Color(0xFFFF8C00),
        t / 0.33,
      )!;
    } else if (t < 0.66) {
      return Color.lerp(
        const Color(0xFFFF8C00),
        Colors.white,
        (t - 0.33) / 0.33,
      )!;
    } else {
      return Color.lerp(
        Colors.white,
        const Color(0xFFBC8A3A),
        (t - 0.66) / 0.34,
      )!;
    }
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) => true;
}

class FloatingParticles extends StatefulWidget {
  const FloatingParticles({super.key});

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = List.generate(20, (_) => _Particle());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            painter: _ParticlePainter(_particles, _controller.value),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _Particle {
  late double x, y, size, speed;
  late double opacity;
  bool isShootingStar = false; // Initialized directly to avoid late error
  static final math.Random _random = math.Random();

  _Particle() {
    reset();
  }

  void reset() {
    isShootingStar = _random.nextDouble() > 0.85; // 15% chance
    x = _random.nextDouble();
    y = _random.nextDouble();

    if (isShootingStar) {
      size = 1.0 + _random.nextDouble() * 1.5;
      speed = 0.5 + _random.nextDouble() * 1.0;
      opacity = 0.3 + _random.nextDouble() * 0.4;
    } else {
      size = 2 + _random.nextDouble() * 5;
      speed = 0.05 + _random.nextDouble() * 0.15;
      opacity = 0.05 + _random.nextDouble() * 0.15;
    }
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;

  _ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()..style = PaintingStyle.fill;

      if (p.isShootingStar) {
        final progress = (animationValue * p.speed) % 1.2;
        if (progress > 1.0) continue;

        final startX = p.x * size.width;
        final startY = p.y * size.height;
        final endX = startX + 120;
        final endY = startY + 80;

        final curX = startX + (endX - startX) * progress;
        final curY = startY + (endY - startY) * progress;

        final trailPaint = Paint()
          ..strokeWidth = p.size
          ..shader =
              LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: p.opacity),
                ],
                begin: Alignment(
                  startX / size.width * 2 - 1,
                  startY / size.height * 2 - 1,
                ),
                end: Alignment(
                  curX / size.width * 2 - 1,
                  curY / size.height * 2 - 1,
                ),
              ).createShader(
                Rect.fromLTRB(
                  math.min(startX, curX),
                  math.min(startY, curY),
                  math.max(startX, curX),
                  math.max(startY, curY),
                ),
              )
          ..style = PaintingStyle.stroke;

        canvas.drawLine(Offset(startX, startY), Offset(curX, curY), trailPaint);
        paint.color = Colors.white.withValues(alpha: p.opacity);
        canvas.drawCircle(Offset(curX, curY), p.size, paint);
      } else {
        final x =
            (p.x * size.width + (animationValue * p.speed * size.width)) %
            size.width;
        final y =
            (p.y * size.height +
                math.sin(animationValue * 2 * math.pi + p.x) * 20) %
            size.height;

        paint.color = Colors.white.withValues(alpha: p.opacity);
        canvas.drawCircle(Offset(x, y), p.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _PulsingButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _PulsingButton({required this.onPressed});

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final glowIntensity =
            (_animation.value - 1.0) * 10; // Maps 1.0-1.1 to 0.0-1.0
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFBC8A3A,
                  ).withValues(alpha: 0.2 + (glowIntensity * 0.5)),
                  blurRadius: 8 + (glowIntensity * 16),
                  spreadRadius: glowIntensity * 4,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: ElevatedButton(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFBC8A3A), // Gold accent
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          elevation: 0, // Shadow is handled by the Animated Container
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: Color(0xFFBC8A3A),
        ),
      ),
    );
  }
}

class _BreathingWrapper extends StatefulWidget {
  final Widget child;
  const _BreathingWrapper({required this.child});

  @override
  State<_BreathingWrapper> createState() => _BreathingWrapperState();
}

class _BreathingWrapperState extends State<_BreathingWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _opacityAnimation.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}
