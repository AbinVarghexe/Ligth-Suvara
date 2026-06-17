import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sundayschool_app/providers/saints_provider.dart';
import 'package:sundayschool_app/utils/app_launcher.dart';
import 'package:sundayschool_app/calendar_pdf_viewer_screen.dart';
import 'package:sundayschool_app/calendar_webview_screen.dart';
import 'package:sundayschool_app/login_screen.dart'; // For CustomPageRoute

// Helper to extract YouTube video ID from standard or shortened URLs
String? _getYouTubeId(String url) {
  final regExp = RegExp(
    r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
  );
  final match = regExp.firstMatch(url);
  return (match != null && match.group(2)!.length == 11)
      ? match.group(2)
      : null;
}

class SaintsScreen extends StatefulWidget {
  const SaintsScreen({super.key});

  @override
  State<SaintsScreen> createState() => _SaintsScreenState();
}

class _SaintsScreenState extends State<SaintsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTap(BuildContext context, SaintResourceItem item) {
    final lowerUrl = item.url.toLowerCase();
    final isYoutube =
        item.type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be');
    final ytId = _getYouTubeId(item.url);

    // If the item has text content, media content, or is a YouTube video, open the rich detail screen
    final hasContent = item.content != null && item.content!.trim().isNotEmpty;
    final hasMedia =
        (item.mediaUrl != null && item.mediaUrl!.trim().isNotEmpty) ||
        (isYoutube && ytId != null);

    if (hasContent || hasMedia) {
      Navigator.push(
        context,
        CustomPageRoute(child: SaintResourceDetailScreen(item: item)),
      );
    } else {
      // Otherwise, open the URL directly as before
      _openResourceUrl(context, item);
    }
  }

  void _openResourceUrl(BuildContext context, SaintResourceItem item) {
    final url = item.url.trim();
    if (url.isEmpty) return;

    final lowerUrl = url.toLowerCase();
    final isYoutube =
        item.type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be');
    final isDrive =
        item.type == 'drive' || lowerUrl.contains('drive.google.com');
    final isPdf =
        item.type == 'pdf' ||
        lowerUrl.contains('.pdf') ||
        lowerUrl.contains('firebasestorage') ||
        lowerUrl.contains('/o/');

    if (isYoutube || isDrive) {
      AppLauncher.launchURL(url);
    } else if (isPdf) {
      Navigator.push(
        context,
        CustomPageRoute(
          child: CalendarPdfViewerScreen(url: url, title: item.title),
        ),
      );
    } else {
      // General web link
      Navigator.push(
        context,
        CustomPageRoute(
          child: CalendarWebViewScreen(url: url, title: item.title),
        ),
      );
    }
  }

  IconData _getResourceIcon(SaintResourceItem item) {
    final lowerUrl = item.url.toLowerCase();
    final type = item.type.toLowerCase();

    if (type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be')) {
      return FontAwesomeIcons.youtube;
    } else if (type == 'drive' || lowerUrl.contains('drive.google.com')) {
      return FontAwesomeIcons.googleDrive;
    } else if (type == 'pdf' || lowerUrl.contains('.pdf')) {
      return FontAwesomeIcons.filePdf;
    } else if (type == 'doc' ||
        type == 'docx' ||
        type == 'ppt' ||
        type == 'pptx') {
      return FontAwesomeIcons.filePowerpoint;
    } else {
      return Icons.language_rounded;
    }
  }

  Color _getResourceIconColor(SaintResourceItem item) {
    final lowerUrl = item.url.toLowerCase();
    final type = item.type.toLowerCase();

    if (type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be')) {
      return const Color(0xFFEF4444); // Red
    } else if (type == 'drive' || lowerUrl.contains('drive.google.com')) {
      return const Color(0xFF22C55E); // Green
    } else if (type == 'pdf' || lowerUrl.contains('.pdf')) {
      return const Color(0xFFDC2626); // Dark Red
    } else if (type == 'doc' ||
        type == 'docx' ||
        type == 'ppt' ||
        type == 'pptx') {
      return const Color(0xFFEAB308); // Gold/Yellow
    } else {
      return const Color(0xFF6366F1); // Indigo
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyColor = Color(0xFF1E3A8A);
    final saintsProvider = Provider.of<SaintsProvider>(context);

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
        child: Column(
          children: [
            // Search Bar Area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: GoogleFonts.outfit(fontSize: 15, color: navyColor),
                  decoration: InputDecoration(
                    hintText: 'Search saints or resources...',
                    hintStyle: GoogleFonts.outfit(
                      color: Colors.grey.shade400,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // Main Content Area
            Expanded(child: _buildMainContent(saintsProvider, navyColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(SaintsProvider provider, Color navyColor) {
    if (provider.isLoading) {
      return _buildShimmerLoader();
    }

    if (provider.error != null) {
      return _buildErrorState(provider.error!, navyColor);
    }

    final data = provider.saintsData;
    if (data == null || data.categories.isEmpty) {
      return _buildEmptyState('No resources found.', navyColor);
    }

    // Filter Categories and Items
    final filteredCategories = data.categories
        .map((cat) {
          final matchesCategoryName = cat.name.toLowerCase().contains(
            _searchQuery,
          );
          final filteredItems = cat.items.where((item) {
            return item.title.toLowerCase().contains(_searchQuery);
          }).toList();

          if (matchesCategoryName) {
            // Keep all items if the category matches
            return SaintCategory(
              id: cat.id,
              name: cat.name,
              description: cat.description,
              content: cat.content,
              mediaUrl: cat.mediaUrl,
              items: cat.items,
            );
          } else if (filteredItems.isNotEmpty) {
            // Keep only matching items
            return SaintCategory(
              id: cat.id,
              name: cat.name,
              description: cat.description,
              content: cat.content,
              mediaUrl: cat.mediaUrl,
              items: filteredItems,
            );
          }
          return null;
        })
        .whereType<SaintCategory>()
        .toList();

    if (filteredCategories.isEmpty) {
      return _buildEmptyState(
        'No matches found for "$_searchQuery".',
        navyColor,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchSaintsData(),
      color: navyColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredCategories.length,
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          return _buildCategoryCard(category, navyColor);
        },
      ),
    );
  }

  Widget _buildCategoryCard(SaintCategory category, Color navyColor) {
    final hasCategoryMedia =
        category.mediaUrl != null && category.mediaUrl!.trim().isNotEmpty;
    final hasCategoryContent =
        category.content != null && category.content!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: const Color(0xFFBC8A3A),
          collapsedIconColor: Colors.grey.shade400,
          title: Text(
            category.name,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: navyColor,
            ),
          ),
          subtitle:
              category.description != null && category.description!.isNotEmpty
              ? Text(
                  category.description!,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Display category image/banner if available
            if (hasCategoryMedia)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: category.mediaUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            // Display category biography/content text if available
            if (hasCategoryContent)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                child: Text(
                  category.content!,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            // Display resource items
            ...category.items.map(
              (item) => _buildResourceTile(item, navyColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceTile(SaintResourceItem item, Color navyColor) {
    final icon = _getResourceIcon(item);
    final iconColor = _getResourceIconColor(item);
    final lowerUrl = item.url.toLowerCase();
    final isYoutube =
        item.type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be');
    final ytId = _getYouTubeId(item.url);

    final hasItemMedia =
        (item.mediaUrl != null && item.mediaUrl!.trim().isNotEmpty) ||
        (isYoutube && ytId != null);
    final displayMediaUrl =
        (item.mediaUrl != null && item.mediaUrl!.trim().isNotEmpty)
        ? item.mediaUrl!
        : (isYoutube && ytId != null
              ? 'https://img.youtube.com/vi/$ytId/mqdefault.jpg'
              : null);
    final hasItemContent =
        item.content != null && item.content!.trim().isNotEmpty;

    return InkWell(
      onTap: () => _onItemTap(context, item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // If item has a custom media image or YouTube thumbnail, render a small preview thumbnail
            if (hasItemMedia && displayMediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: displayMediaUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 50,
                          height: 50,
                          color: iconColor.withValues(alpha: 0.1),
                          child: Icon(icon, color: iconColor, size: 18),
                        ),
                      ),
                      if (isYoutube)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: navyColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasItemContent
                        ? 'Read Article & Media'
                        : _getResourceTypeName(item),
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getResourceTypeName(SaintResourceItem item) {
    final type = item.type.toLowerCase();
    final lowerUrl = item.url.toLowerCase();

    if (type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be')) {
      return 'YouTube Video';
    } else if (type == 'drive' || lowerUrl.contains('drive.google.com')) {
      return 'Google Drive Folder / File';
    } else if (type == 'pdf' || lowerUrl.contains('.pdf')) {
      return 'PDF Document';
    } else {
      return 'Web Reference';
    }
  }

  Widget _buildEmptyState(String message, Color navyColor) {
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
                Icons.library_books_rounded,
                size: 64,
                color: navyColor.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saints Found',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, Color navyColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to Load Resources',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }
}

class SaintResourceDetailScreen extends StatelessWidget {
  final SaintResourceItem item;

  const SaintResourceDetailScreen({super.key, required this.item});

  void _openUrl(BuildContext context) {
    final url = item.url.trim();
    if (url.isEmpty) return;

    final lowerUrl = url.toLowerCase();
    final isYoutube =
        item.type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be');
    final isDrive =
        item.type == 'drive' || lowerUrl.contains('drive.google.com');
    final isPdf =
        item.type == 'pdf' ||
        lowerUrl.contains('.pdf') ||
        lowerUrl.contains('firebasestorage') ||
        lowerUrl.contains('/o/');

    if (isYoutube || isDrive) {
      AppLauncher.launchURL(url);
    } else if (isPdf) {
      Navigator.push(
        context,
        CustomPageRoute(
          child: CalendarPdfViewerScreen(url: url, title: item.title),
        ),
      );
    } else {
      Navigator.push(
        context,
        CustomPageRoute(
          child: CalendarWebViewScreen(url: url, title: item.title),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const navyColor = Color(0xFF1E3A8A);
    final lowerUrl = item.url.toLowerCase();
    final isYoutube =
        item.type == 'youtube' ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be');
    final ytId = _getYouTubeId(item.url);

    final hasMedia =
        (item.mediaUrl != null && item.mediaUrl!.trim().isNotEmpty) ||
        (isYoutube && ytId != null);
    final displayMediaUrl =
        (item.mediaUrl != null && item.mediaUrl!.trim().isNotEmpty)
        ? item.mediaUrl!
        : (isYoutube && ytId != null
              ? 'https://img.youtube.com/vi/$ytId/0.jpg'
              : null);
    final hasUrl = item.url.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Header / Hero Image Banner
          SliverAppBar(
            expandedHeight: hasMedia ? 280 : 120,
            pinned: true,
            elevation: 0,
            backgroundColor: navyColor,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 24, 16),
              background: hasMedia && displayMediaUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: displayMediaUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: navyColor,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: navyColor,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white24,
                              size: 60,
                            ),
                          ),
                        ),
                        // Soft dark gradient overlay for title contrast
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                        if (isYoutube)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            ),
          ),

          // Content Details Area
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.content != null &&
                      item.content!.trim().isNotEmpty) ...[
                    Text(
                      item.content!,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  if (hasUrl)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openUrl(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                        icon: Icon(
                          isYoutube
                              ? FontAwesomeIcons.youtube
                              : Icons.launch_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isYoutube ? 'Watch Video' : 'Open Reference Material',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
