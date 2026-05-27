// lib/video_resources_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sundayschool_app/utils/app_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoResourcesScreen extends StatefulWidget {
  const VideoResourcesScreen({super.key});

  @override
  State<VideoResourcesScreen> createState() => _VideoResourcesScreenState();
}

class _VideoResourcesScreenState extends State<VideoResourcesScreen>
    with TickerProviderStateMixin {
  int? _selectedClass; // null means "show main grid class selector"
  late AnimationController _fadeController;

  // Metadata for the 12 classes to make them highly aesthetic
  final List<ClassMetadata> _classConfig = [
    ClassMetadata(
      classNum: 1,
      tagline: 'First Steps of Faith',
      icon: FontAwesomeIcons.child,
      colors: [Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink to Rose
    ),
    ClassMetadata(
      classNum: 2,
      tagline: 'God\'s Little Lambs',
      icon: FontAwesomeIcons.dove,
      colors: [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal to Dark Teal
    ),
    ClassMetadata(
      classNum: 3,
      tagline: 'Learning to Pray',
      icon: FontAwesomeIcons.handsPraying,
      colors: [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber to Orange
    ),
    ClassMetadata(
      classNum: 4,
      tagline: 'Stories of Jesus',
      icon: FontAwesomeIcons.cross,
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Blue to Royal Blue
    ),
    ClassMetadata(
      classNum: 5,
      tagline: 'Living in Love',
      icon: FontAwesomeIcons.solidHeart,
      colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Purple to Violet
    ),
    ClassMetadata(
      classNum: 6,
      tagline: 'Gifts of the Spirit',
      icon: FontAwesomeIcons.fire,
      colors: [Color(0xFFEF4444), Color(0xFFDC2626)], // Red to Dark Red
    ),
    ClassMetadata(
      classNum: 7,
      tagline: 'The Holy Bible',
      icon: FontAwesomeIcons.bookOpen,
      colors: [Color(0xFF06B6D4), Color(0xFF0891B2)], // Cyan to Dark Cyan
    ),
    ClassMetadata(
      classNum: 8,
      tagline: 'Walking with Christ',
      icon: FontAwesomeIcons.shoePrints,
      colors: [Color(0xFF10B981), Color(0xFF059669)], // Green to Dark Green
    ),
    ClassMetadata(
      classNum: 9,
      tagline: 'Light of the World',
      icon: FontAwesomeIcons.solidLightbulb,
      colors: [Color(0xFFEAB308), Color(0xFFCA8A04)], // Yellow to Dark Yellow
    ),
    ClassMetadata(
      classNum: 10,
      tagline: 'Soldiers of Truth',
      icon: FontAwesomeIcons.shieldHalved,
      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)], // Indigo to Royal Indigo
    ),
    ClassMetadata(
      classNum: 11,
      tagline: 'Faith in Action',
      icon: FontAwesomeIcons.graduationCap,
      colors: [Color(0xFF475569), Color(0xFF334155)], // Slate to Dark Slate
    ),
    ClassMetadata(
      classNum: 12,
      tagline: 'Disciples for Life',
      icon: FontAwesomeIcons.crown,
      colors: [Color(0xFFD4AF37), Color(0xFFAA7C11)], // Gold to Dark Gold
    ),
  ];


  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<DocumentSnapshot>? _resourcesFuture;

  void _selectClass(int classNum) {
    setState(() {
      _selectedClass = classNum;
      _resourcesFuture = FirebaseFirestore.instance
          .collection('video_resources')
          .doc('class_$_selectedClass')
          .get();
    });
  }

  void _backToGrid() {
    setState(() {
      _selectedClass = null;
      _resourcesFuture = null;
    });
  }

  void _playYoutubeVideo(String videoId, String title) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyColor = Color(0xFF1E3A8A);

    return PopScope(
      canPop: _selectedClass == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_selectedClass != null) {
            _backToGrid();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: navyColor,
                    size: 18,
                  ),
                  onPressed: () {
                    if (_selectedClass != null) {
                      _backToGrid();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),
          title: Text(
            _selectedClass == null
                ? 'Video Resources'
                : 'Class $_selectedClass',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: navyColor,
            ),
          ),
          centerTitle: true,
          // dev actions icon button removed
        ),
        body: FadeTransition(
          opacity: _fadeController,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedClass == null
                ? _buildMainClassGrid(navyColor)
                : _buildClassResourcesView(navyColor),
          ),
        ),
      ),
    );
  }



  // --- VIEW 1: BEAUTIFUL CLASS TILES/GRID ---
  Widget _buildMainClassGrid(Color navyColor) {
    return Container(
      key: const ValueKey('grid_view'),
      color: const Color(0xFFF8FAFC),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Your Class',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: navyColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose a class below to explore',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.15,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final config = _classConfig[index];
                return _buildClassTile(config, navyColor);
              }, childCount: 12),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildClassTile(ClassMetadata config, Color navyColor) {
    return _PressableCard(
      onTap: () => _selectClass(config.classNum),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: config.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: config.colors.first.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(config.icon, size: 110, color: Colors.white),
                ),
              ),
              Positioned(
                left: -10,
                top: -10,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            config.icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        Text(
                          config.classNum.toString().padLeft(2, '0'),
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class ${config.classNum}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          config.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
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

  // --- VIEW 2: CLASS RESOURCES CONTENT ---
  Widget _buildClassResourcesView(Color navyColor) {
    // Quick Class Switcher removed, layout redesigned
    return Container(
      key: ValueKey('resources_view_$_selectedClass'),
      color: const Color(0xFFF8FAFC),
      child: _buildResourcesList(navyColor),
    );
  }

  Widget _buildResourcesList(Color navyColor) {
    final activeConfig = _classConfig[_selectedClass! - 1];

    return FutureBuilder<DocumentSnapshot>(
      future: _resourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading resources: ${snapshot.error}',
              style: GoogleFonts.outfit(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildEmptyState(navyColor);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final chapters = data?['chapters'] as List<dynamic>? ?? [];

        if (chapters.isEmpty) {
          return _buildEmptyState(navyColor);
        }

        return CustomScrollView(
          key: ValueKey('resources_scroll_$_selectedClass'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Dynamic Header Banner
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: activeConfig.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: activeConfig.colors.first.withValues(alpha: 0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        activeConfig.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Class $_selectedClass',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeConfig.tagline,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chapters List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final chapter = chapters[index] as Map<String, dynamic>;
                  final chapterTitle = chapter['title'] ?? 'Untitled Chapter';
                  final resources =
                      chapter['resources'] as List<dynamic>? ?? [];

                  return _AnimatedChapterCard(
                    title: chapterTitle,
                    resources: resources,
                    navyColor: navyColor,
                    accentColor: activeConfig.colors.first,
                    onPlayYoutube: _playYoutubeVideo,
                  );
                }, childCount: chapters.length),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(Color navyColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: navyColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 64,
                color: navyColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Resources Available',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We haven\'t added reference slides or videos for Class $_selectedClass yet. Check back soon!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- REDESIGNED INTERACTIVE EXPANDABLE CHAPTER CARD ---

class _AnimatedChapterCard extends StatefulWidget {
  final String title;
  final List<dynamic> resources;
  final Color navyColor;
  final Color accentColor;
  final Function(String videoId, String title) onPlayYoutube;

  const _AnimatedChapterCard({
    required this.title,
    required this.resources,
    required this.navyColor,
    required this.accentColor,
    required this.onPlayYoutube,
  });

  @override
  State<_AnimatedChapterCard> createState() => _AnimatedChapterCardState();
}

class _AnimatedChapterCardState extends State<_AnimatedChapterCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  String? _getYouTubeId(String url) {
    final regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
    );
    final match = regExp.firstMatch(url);
    return (match != null && match.group(2)!.length == 11)
        ? match.group(2)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    // Count different resource types
    int videoCount = 0;
    int docCount = 0;
    for (var r in widget.resources) {
      final res = r as Map<String, dynamic>;
      final url = res['url'] ?? '';
      final type = res['type'] ?? 'link';
      final isYoutube =
          type == 'youtube' ||
          url.toString().contains('youtube.com') ||
          url.toString().contains('youtu.be');
      if (isYoutube) {
        videoCount++;
      } else {
        docCount++;
      }
    }

    String statsText = '';
    if (videoCount > 0) {
      statsText += '$videoCount Video${videoCount > 1 ? 's' : ''}';
    }
    if (docCount > 0) {
      if (statsText.isNotEmpty) statsText += '  •  ';
      statsText += '$docCount Document${docCount > 1 ? 's' : ''}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Chapter Header Trigger
            InkWell(
              onTap: _toggleExpand,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        FontAwesomeIcons.bookOpenReader,
                        color: widget.accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: widget.navyColor,
                            ),
                          ),
                          if (statsText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              statsText,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: Tween(
                        begin: 0.0,
                        end: 0.5,
                      ).animate(_expandAnimation),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: widget.navyColor.withValues(alpha: 0.6),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded Resources View
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: widget.resources.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'No resources in this chapter.',
                              style: GoogleFonts.outfit(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ]
                      : widget.resources.map((res) {
                          final resource = res as Map<String, dynamic>;
                          final title = resource['title'] ?? 'Untitled';
                          final url = resource['url'] ?? '';
                          final type = resource['type'] ?? 'link';
                          final isYoutube =
                              type == 'youtube' ||
                              url.toString().contains('youtube.com') ||
                              url.toString().contains('youtu.be');
                          final ytId = isYoutube ? _getYouTubeId(url) : null;

                          return _PremiumResourceCard(
                            title: title,
                            url: url,
                            ytId: ytId,
                            type: type,
                            navyColor: widget.navyColor,
                            accentColor: widget.accentColor,
                            onPlayYoutube: widget.onPlayYoutube,
                          );
                        }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HIGH-FIDELITY RESOURCE CARD WITH PULSING EFFECTS & GRADIENTS ---

class _PremiumResourceCard extends StatefulWidget {
  final String title;
  final String url;
  final String? ytId;
  final String type;
  final Color navyColor;
  final Color accentColor;
  final Function(String videoId, String title) onPlayYoutube;

  const _PremiumResourceCard({
    required this.title,
    required this.url,
    required this.ytId,
    required this.type,
    required this.navyColor,
    required this.accentColor,
    required this.onPlayYoutube,
  });

  @override
  State<_PremiumResourceCard> createState() => _PremiumResourceCardState();
}

class _PremiumResourceCardState extends State<_PremiumResourceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ytId != null) {
      final thumbUrl =
          'https://img.youtube.com/vi/${widget.ytId}/maxresdefault.jpg';
      return _PressableCard(
        onTap: () => widget.onPlayYoutube(widget.ytId!, widget.title),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.network(
                              'https://img.youtube.com/vi/${widget.ytId}/0.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                      ),
                      // Soft overlay gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Pulsing Play Button
                      Center(
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent,
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      // Duration badge or play tag
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FontAwesomeIcons.youtube,
                                color: Colors.red,
                                size: 12,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Watch Video',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: widget.navyColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // PPT / Google Drive Attachment
      final isDrive =
          widget.type == 'drive' || widget.url.contains('drive.google.com');

      return _PressableCard(
        onTap: () => AppLauncher.launchURL(widget.url),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFFAFBFD),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDrive
                      ? Colors.blue.withValues(alpha: 0.1)
                      : widget.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDrive
                      ? Icons.insert_drive_file_rounded
                      : Icons.link_rounded,
                  color: isDrive ? Colors.blue.shade700 : widget.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: widget.navyColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isDrive ? 'Google Drive Reference' : 'Reference Document',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

// --- PRE-EXISTING WIDGET HELPER IMPLEMENTATIONS ---

class ClassMetadata {
  final int classNum;
  final String tagline;
  final IconData icon;
  final List<Color> colors;

  ClassMetadata({
    required this.classNum,
    required this.tagline,
    required this.icon,
    required this.colors,
  });
}

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 100),
          lowerBound: 0.0,
          upperBound: 0.05,
        )..addListener(() {
          setState(() {});
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: Transform.scale(scale: _scale, child: widget.child),
    );
  }
}
