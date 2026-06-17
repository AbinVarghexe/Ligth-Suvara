// lib/video_resources_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sundayschool_app/utils/app_launcher.dart';
import 'package:sundayschool_app/calendar_webview_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

// --- DATA MODELS ---

class ResourceSection {
  final String id;
  final String title;
  final String iconName;
  final Color themeColor;
  final int order;

  ResourceSection({
    required this.id,
    required this.title,
    required this.iconName,
    required this.themeColor,
    required this.order,
  });

  factory ResourceSection.fromMap(Map<String, dynamic> map) {
    return ResourceSection(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      iconName: map['icon'] ?? 'GraduationCap',
      themeColor: _parseColor(map['customColor']),
      order: map['order'] ?? 0,
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}

// --- UTILITY FOR ICON MAPPING ---

IconData getSectionIcon(String iconName) {
  switch (iconName) {
    case 'GraduationCap':
      return Icons.school_rounded;
    case 'BookOpen':
      return Icons.menu_book_rounded;
    case 'Youtube':
      return Icons.play_circle_fill_rounded;
    case 'Music':
      return Icons.music_note_rounded;
    case 'Film':
      return Icons.movie_rounded;
    case 'FileText':
      return Icons.description_rounded;
    case 'FolderDot':
      return Icons.folder_rounded;
    case 'HelpCircle':
      return Icons.help_outline_rounded;
    case 'Heart':
      return Icons.favorite_rounded;
    case 'Trophy':
      return Icons.emoji_events_rounded;
    case 'Calendar':
      return Icons.calendar_today_rounded;
    case 'Info':
      return Icons.info_outline_rounded;
    case 'Play':
      return Icons.play_arrow_rounded;
    case 'Bookmark':
      return Icons.bookmark_rounded;
    case 'MapPin':
      return Icons.location_on_rounded;
    case 'Image':
      return Icons.image_rounded;
    default:
      return Icons.grid_view_rounded;
  }
}

// --- VIEW 1: DYNAMIC BUTTONS SCREEN (DASHBOARD) ---

class VideoResourcesScreen extends StatefulWidget {
  final String? initialSectionId;
  final String? initialSectionTitle;
  final Color? initialSectionColor;

  const VideoResourcesScreen({
    super.key,
    this.initialSectionId,
    this.initialSectionTitle,
    this.initialSectionColor,
  });

  @override
  State<VideoResourcesScreen> createState() => _VideoResourcesScreenState();
}

class _VideoResourcesScreenState extends State<VideoResourcesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

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

  @override
  Widget build(BuildContext context) {
    if (widget.initialSectionId != null) {
      return ChapterDetailsScreen(
        sectionId: widget.initialSectionId!,
        title: widget.initialSectionTitle ?? 'Resources',
        themeColor: widget.initialSectionColor ?? const Color(0xFF1E3A8A),
      );
    }

    const navyColor = Color(0xFF1E3A8A);

    return Scaffold(
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
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        title: Text(
          'Resources',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: navyColor,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeController,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('video_resources')
              .doc('sections_config')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerGrid();
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
            final sectionsRaw = data?['sections'] as List<dynamic>? ?? [];

            if (sectionsRaw.isEmpty) {
              return _buildEmptyState(navyColor);
            }

            final List<ResourceSection> sections = sectionsRaw
                .map((s) => ResourceSection.fromMap(Map<String, dynamic>.from(s)))
                .toList();

            // Sort sections by their 'order' value
            sections.sort((a, b) => a.order.compareTo(b.order));

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Learning Center',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: navyColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Access all reference slides, quiz content, presentations, and teaching videos.',
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final section = sections[index];
                        return _buildSectionTile(context, section, navyColor);
                      },
                      childCount: sections.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTile(
      BuildContext context, ResourceSection section, Color navyColor) {
    final colors = [section.themeColor, section.themeColor.withValues(alpha: 0.8)];
    return _PressableCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChapterDetailsScreen(
              sectionId: section.id,
              title: section.title,
              themeColor: section.themeColor,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.25),
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
                  child: Icon(
                    getSectionIcon(section.iconName),
                    size: 110,
                    color: Colors.white,
                  ),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        getSectionIcon(section.iconName),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
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
                Icons.grid_view_rounded,
                size: 64,
                color: navyColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Resource Sections Configured',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'It looks like there are no active dynamic sections set up in the dashboard. Check back soon!',
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

  Widget _buildShimmerGrid() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.15,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
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

// --- VIEW 2: CHAPTER DETAILS SCREEN ---

class ChapterDetailsScreen extends StatefulWidget {
  final String sectionId;
  final String title;
  final Color themeColor;

  const ChapterDetailsScreen({
    super.key,
    required this.sectionId,
    required this.title,
    required this.themeColor,
  });

  @override
  State<ChapterDetailsScreen> createState() => _ChapterDetailsScreenState();
}

class _ChapterDetailsScreenState extends State<ChapterDetailsScreen> {
  void _playYoutubeVideo(String videoId, String title) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyColor = Color(0xFF1E3A8A);

    return Scaffold(
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
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: navyColor,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('video_resources')
            .doc(widget.sectionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerLoader();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading chapters: ${snapshot.error}',
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
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Dynamic Header Banner
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.themeColor, widget.themeColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: widget.themeColor.withValues(alpha: 0.25),
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
                        child: const Icon(
                          Icons.menu_book_rounded,
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
                              widget.title,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Explore content documents and videos',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
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
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final chapter = chapters[index] as Map<String, dynamic>;
                      final chapterTitle = chapter['title'] ?? 'Untitled Chapter';
                      final resources = chapter['resources'] as List<dynamic>? ?? [];

                      return _AnimatedChapterCard(
                        title: chapterTitle,
                        resources: resources,
                        navyColor: navyColor,
                        accentColor: widget.themeColor,
                        onPlayYoutube: _playYoutubeVideo,
                      );
                    },
                    childCount: chapters.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
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
                Icons.folder_open_rounded,
                size: 64,
                color: navyColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Chapters Found',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We haven\'t added reference slides or videos for this section yet. Check back soon!',
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
          itemCount: 4,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 100,
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

// --- INTERACTIVE EXPANDABLE CHAPTER CARD ---

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
    int videoCount = 0;
    int docCount = 0;
    for (var r in widget.resources) {
      final res = r as Map<String, dynamic>;
      final url = res['url'] ?? '';
      final type = res['type'] ?? 'link';
      final isYoutube = type == 'youtube' ||
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
      statsText += '$docCount Item${docCount > 1 ? 's' : ''}';
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
                      turns: Tween(begin: 0.0, end: 0.5).animate(_expandAnimation),
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
                          final isYoutube = type == 'youtube' ||
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

// --- RESOURCE CARD WITH PULSING EFFECTS & GRADIENTS ---

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

  IconData getResourceTypeIcon(String type, String url) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'pdf') return Icons.picture_as_pdf_rounded;
    if (lowerType == 'ppt' || lowerType == 'slides') return Icons.slideshow_rounded;
    if (lowerType == 'quiz') return Icons.quiz_rounded;
    if (lowerType == 'drive' || url.contains('drive.google.com')) {
      return Icons.insert_drive_file_rounded;
    }
    return Icons.link_rounded;
  }

  Color getResourceTypeColor(String type, String url, Color defaultColor) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'pdf') return Colors.red.shade700;
    if (lowerType == 'ppt' || lowerType == 'slides') return Colors.orange.shade700;
    if (lowerType == 'quiz') return Colors.purple.shade700;
    if (lowerType == 'drive' || url.contains('drive.google.com')) {
      return Colors.blue.shade700;
    }
    return defaultColor;
  }

  String getResourceTypeLabel(String type, String url) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'pdf') return 'PDF Document';
    if (lowerType == 'ppt' || lowerType == 'slides') return 'Presentation Slide';
    if (lowerType == 'quiz') return 'Interactive Quiz';
    if (lowerType == 'drive' || url.contains('drive.google.com')) {
      return 'Google Drive Reference';
    }
    return 'Reference Link';
  }

  void _handleTap(BuildContext context) {
    final typeLower = widget.type.toLowerCase();
    if (typeLower == 'quiz' || typeLower == 'link') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarWebViewScreen(url: widget.url, title: widget.title),
        ),
      );
    } else {
      AppLauncher.launchURL(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ytId != null) {
      final thumbUrl = 'https://img.youtube.com/vi/${widget.ytId}/maxresdefault.jpg';
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
                        errorBuilder: (context, error, stackTrace) => Image.network(
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
      // Attachment style card for PDF / PPT / Drive / Link / Quiz etc.
      final resIcon = getResourceTypeIcon(widget.type, widget.url);
      final resColor = getResourceTypeColor(widget.type, widget.url, widget.accentColor);
      final resLabel = getResourceTypeLabel(widget.type, widget.url);

      return _PressableCard(
        onTap: () => _handleTap(context),
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
                  color: resColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resIcon,
                  color: resColor,
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
                      resLabel,
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

// --- WIDGET HELPER IMPLEMENTATION ---

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
    _controller = AnimationController(
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
