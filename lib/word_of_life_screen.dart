// lib/word_of_life_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sundayschool_app/providers/word_of_life_provider.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';
import 'package:sundayschool_app/widgets/word_of_life_video_player.dart';

Widget _buildYoutubeThumbnail(String videoId, {required double height, required BoxFit fit}) {
  return CachedNetworkImage(
    imageUrl: 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
    fit: fit,
    width: double.infinity,
    height: height,
    placeholder: (context, url) => Container(
      color: Colors.black12,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      ),
    ),
    errorWidget: (context, url, error) => CachedNetworkImage(
      imageUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      fit: fit,
      width: double.infinity,
      height: height,
      placeholder: (context, url) => Container(color: Colors.black12),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF0F766E),
        child: const Center(
          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white54, size: 48),
        ),
      ),
    ),
  );
}

Future<void> _launchYoutube(String url) async {
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (e) {
    debugPrint('Error launching youtube: $e');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class WordOfLifeScreen extends StatefulWidget {
  const WordOfLifeScreen({super.key});
  @override
  State<WordOfLifeScreen> createState() => _WordOfLifeScreenState();
}

class _WordOfLifeScreenState extends State<WordOfLifeScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;

  static const _tealDark  = Color(0xFF0F766E);
  static const _tealMid   = Color(0xFF0D9488);
  static const _navyColor = Color(0xFF1E3A8A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFB),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
          child: Consumer<WordOfLifeProvider>(
            builder: (context, provider, _) {
              final active  = provider.entries.where((e) => e.isActive && !e.isExpired).toList();
              final archive = provider.entries.where((e) => e.isExpired).toList();

              return NestedScrollView(
                headerSliverBuilder: (ctx, inner) => [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(ctx),
                    sliver: _buildSliverAppBar(inner, hasArchive: archive.isNotEmpty),
                  ),
                ],
                body: provider.isLoading
                    ? _buildShimmer()
                    : provider.error != null
                        ? _buildErrorState(provider)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _ActiveTab(entries: active, tealMid: _tealMid, tabController: _tabController),
                              _ArchiveTab(entries: archive, tealMid: _tealMid, navyColor: _navyColor),
                            ],
                          ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(bool inner, {required bool hasArchive}) {
    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      forceElevated: inner,
      elevation: 0,
      backgroundColor: _tealDark,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 17),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 52),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ജീവന്റെ വചനം',
                style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8))),
            Text('Word of Life',
                style: GoogleFonts.outfit(
                  fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
        background: _AppBarBg(tealDark: _tealDark, tealMid: _tealMid),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
        tabs: [
          const Tab(text: 'This week'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Archive'),
                if (hasArchive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_edu_rounded,
                        size: 13, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── States ───────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _shimmerBox(height: 360, radius: 28),
          const SizedBox(height: 14),
          _shimmerBox(height: 130, radius: 20),
          const SizedBox(height: 12),
          _shimmerBox(height: 130, radius: 20),
        ]),
      ),
    );
  }

  Widget _shimmerBox({required double height, required double radius}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 0),
        height: height,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      );

  Widget _buildErrorState(WordOfLifeProvider p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 52),
              const SizedBox(height: 16),
              Text('Could not load verses',
                  style: GoogleFonts.outfit(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: _navyColor)),
              const SizedBox(height: 8),
              Text(p.error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: p.refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tealMid,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  APP BAR BACKGROUND (extracted widget for cleanliness)
// ══════════════════════════════════════════════════════════════════════════════
class _AppBarBg extends StatelessWidget {
  final Color tealDark, tealMid;
  const _AppBarBg({required this.tealDark, required this.tealMid});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tealDark, tealMid, const Color(0xFF14B8A6)],
          ),
        ),
      ),
      Positioned(
        right: -20, top: 0,
        child: Opacity(
          opacity: 0.08,
          child: const Icon(Icons.menu_book_rounded, size: 190, color: Colors.white),
        ),
      ),
      Positioned(
        left: 20, bottom: 70,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (i) => Container(
            margin: const EdgeInsets.only(bottom: 7),
            width: 55.0 + i * 28, height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ),
      ),
      Positioned(
        bottom: 0, left: 0, right: 0, height: 80,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTIVE TAB
// ══════════════════════════════════════════════════════════════════════════════
class _ActiveTab extends StatefulWidget {
  final List<WordOfLifeEntry> entries;
  final Color tealMid;
  final TabController tabController;
  const _ActiveTab({
    required this.entries,
    required this.tealMid,
    required this.tabController,
  });

  @override
  State<_ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<_ActiveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entries = widget.entries;
    final tealMid = widget.tealMid;
    if (entries.isEmpty) {
      return _EmptyState(
        icon: Icons.menu_book_rounded,
        title: 'No Current Verse',
        subtitle: 'The Word of Life for this period will appear here once published.',
        color: tealMid,
      );
    }
    
    return RefreshIndicator(
      key: const PageStorageKey('word_of_life_active_tab_root'),
      onRefresh: () => context.read<WordOfLifeProvider>().refresh(),
      color: tealMid,
      child: CustomScrollView(
        key: const PageStorageKey('word_of_life_active_list'),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ActiveCard(
                  key: ValueKey(entries[i].id),
                  entry: entries[i],
                  isHero: i == 0,
                ),
                childCount: entries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTIVE CARD — tap to open detail
// ══════════════════════════════════════════════════════════════════════════════
class _ActiveCard extends StatefulWidget {
  final WordOfLifeEntry entry;
  final bool isHero;
  const _ActiveCard({
    super.key,
    required this.entry,
    required this.isHero,
  });
  @override
  State<_ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends State<_ActiveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  bool _isPlaying = false;

  static const _tealMid  = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => WordOfLifeDetailScreen(entry: widget.entry),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06), end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final hasRef       = e.reference != null && e.reference!.isNotEmpty;
    final hasReflect   = e.reflection != null && e.reflection!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.isHero ? 20 : 14),
      child: Hero(
        tag: 'wol_${e.id}',
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _tealMid.withValues(alpha: widget.isHero ? 0.22 : 0.10),
                  blurRadius: widget.isHero ? 30 : 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── TOP: Image, video, or gradient header ──
                  if (e.hasVideo && e.isYoutubeVideo)
                    GestureDetector(
                      onTap: () => _launchYoutube(e.resolvedVideoUrl!),
                      child: AspectRatio(
                        aspectRatio: e.resolvedAspectRatio,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildYoutubeThumbnail(
                              e.youtubeVideoId ?? '',
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              color: Colors.black.withOpacity(0.2),
                            ),
                            Center(
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 42,
                                ),
                              ),
                            ),
                            // ACTIVE badge (top-left)
                            Positioned(
                              top: 14, left: 14,
                              child: IgnorePointer(
                                child: _ActiveBadge(
                                  pulse: widget.isHero ? _scale : null,
                                ),
                              ),
                            ),
                            // Date pill (top-right)
                            if (e.startDate != null || e.endDate != null)
                              Positioned(
                                top: 14, right: 14,
                                child: IgnorePointer(
                                  child: _DateRangePill(entry: e),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else if (e.hasVideo)
                    AspectRatio(
                      aspectRatio: e.resolvedAspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          WordOfLifeVideoPlayer(entry: e),
                          // ACTIVE badge (top-left)
                          Positioned(
                            top: 14, left: 14,
                            child: IgnorePointer(
                              child: _ActiveBadge(
                                pulse: widget.isHero ? _scale : null,
                              ),
                            ),
                          ),
                          // Date pill (top-right)
                          if (e.startDate != null || e.endDate != null)
                            Positioned(
                              top: 14, right: 14,
                              child: IgnorePointer(
                                child: _DateRangePill(entry: e),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => _openDetail(context),
                      child: AspectRatio(
                        aspectRatio: widget.isHero ? 1.4 : 1.6,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (e.hasImage)
                              CachedNetworkImage(
                                imageUrl: e.imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _gradientHeader(height: double.infinity),
                                errorWidget: (_, __, ___) => _gradientHeader(height: double.infinity),
                              )
                            else
                              _gradientHeader(height: double.infinity),

                            // ACTIVE badge (top-left)
                            Positioned(
                              top: 14, left: 14,
                              child: IgnorePointer(
                                child: _ActiveBadge(
                                  pulse: widget.isHero ? _scale : null,
                                ),
                              ),
                            ),

                            // Date pill (top-right)
                            if (e.startDate != null || e.endDate != null)
                              Positioned(
                                top: 14, right: 14,
                                child: IgnorePointer(
                                  child: _DateRangePill(entry: e),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // ── BOTTOM: Details section ──
                  GestureDetector(
                    onTap: () => _openDetail(context),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            const Color(0xFFF0FDFB).withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [


                          if (e.hasVideo && e.hasImage) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: e.imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _gradientHeader(),
                                errorWidget: (_, __, ___) => _gradientHeader(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Quote mark + Verse
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('\u201C',
                                  style: GoogleFonts.libreBaskerville(
                                    fontSize: widget.isHero ? 52 : 40,
                                    color: _tealMid.withValues(alpha: 0.28),
                                    height: 0.75,
                                  )),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(e.verse,
                                    maxLines: widget.isHero ? null : 5,
                                    overflow: widget.isHero
                                        ? null
                                        : TextOverflow.ellipsis,
                                    style: GoogleFonts.libreBaskerville(
                                      fontSize: widget.isHero ? 18 : 15,
                                      fontStyle: FontStyle.italic,
                                      color: const Color(0xFF1E3A8A),
                                      height: 1.7,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ],
                          ),

                          // Reference chip
                          if (hasRef) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _tealMid.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bookmark_rounded,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 6),
                                  Text(e.reference!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      )),
                                ],
                              ),
                            ),
                          ],

                          // Reflection / Scripture reference grid preview (truncated)
                          if (hasReflect) ...[
                            const SizedBox(height: 14),
                            Builder(
                              builder: (context) {
                                final lines = e.reflection!
                                    .split('\n')
                                    .where((l) => l.trim().isNotEmpty)
                                    .toList();
                                final isRefList = lines.isNotEmpty &&
                                    lines.every((line) => line.length < 50);

                                if (isRefList) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _tealMid.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: _tealMid.withValues(alpha: 0.08)),
                                    ),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: lines.map((line) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _tealMid.withValues(
                                                    alpha: 0.04),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                            border: Border.all(
                                                color: _tealMid.withValues(
                                                    alpha: 0.08)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bookmark_outline_rounded,
                                                  color: _tealMid, size: 12),
                                              const SizedBox(width: 6),
                                              Text(
                                                line.trim(),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF1E3A8A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                } else {
                                  // Render standard reflection preview block
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _tealMid.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: _tealMid.withValues(alpha: 0.12)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.lightbulb_outline_rounded,
                                            color: _tealMid, size: 15),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(e.reflection!,
                                              maxLines: widget.isHero ? 3 : 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13.5,
                                                color: Colors.grey.shade700,
                                                height: 1.55,
                                              )),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ],

                          // Read More button
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF14B8A6).withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Read More',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        )),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 14, color: Colors.white),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _gradientHeader({double? height}) => SizedBox(
        width: double.infinity,
        height: height ?? (widget.isHero ? 260 : 200),
        child: CachedNetworkImage(
          imageUrl: 'https://images.unsplash.com/photo-1504052434569-70ad585e51c7?q=80&w=800&auto=format&fit=crop',
          fit: BoxFit.cover,
          placeholder: (_, __) => _pureGradientHeader(height: height),
          errorWidget: (_, __, ___) => _pureGradientHeader(height: height),
        ),
      );

  Widget _pureGradientHeader({double? height}) => Container(
        width: double.infinity,
        height: height ?? (widget.isHero ? 260 : 200),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
          ),
        ),
        child: Stack(children: [
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.menu_book_rounded,
                size: 64, color: Colors.white24),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
class _ArchiveTab extends StatefulWidget {
  final List<WordOfLifeEntry> entries;
  final Color tealMid, navyColor;
  const _ArchiveTab({required this.entries, required this.tealMid, required this.navyColor});

  @override
  State<_ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<_ArchiveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final entries = widget.entries;
    final tealMid = widget.tealMid;
    final navyColor = widget.navyColor;
    if (entries.isEmpty) {
      return _EmptyState(
        icon: Icons.history_edu_rounded,
        title: 'Archive is Empty',
        subtitle: 'Past Word of Life entries will be preserved here for reflection.',
        color: tealMid,
      );
    }
    return RefreshIndicator(
      key: const PageStorageKey('word_of_life_archive_tab_root'),
      onRefresh: () => context.read<WordOfLifeProvider>().refresh(),
      color: tealMid,
      child: CustomScrollView(
        key: const PageStorageKey('word_of_life_archive_list'),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ArchiveCard(
                  entry: entries[i],
                  tealMid: tealMid,
                  navyColor: navyColor,
                ),
                childCount: entries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final WordOfLifeEntry entry;
  final Color tealMid, navyColor;
  const _ArchiveCard({required this.entry, required this.tealMid, required this.navyColor});

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => WordOfLifeDetailScreen(entry: entry),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim, child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRef = entry.reference != null && entry.reference!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tealMid.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: tealMid.withValues(alpha: 0.04),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left thumbnail (floating image or gradient swatch)
              Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 76, height: 76,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        entry.isYoutubeVideo
                            ? _buildYoutubeThumbnail(
                                entry.youtubeVideoId ?? '',
                                height: 76,
                                fit: BoxFit.cover,
                              )
                            : (entry.hasImage
                                ? CachedNetworkImage(
                                    imageUrl: entry.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => _thumbPlaceholder(),
                                    errorWidget: (_, __, ___) => _thumbPlaceholder(),
                                  )
                                : _thumbPlaceholder()),
                        if (entry.hasVideo)
                          Container(
                            color: Colors.black.withValues(alpha: 0.25),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2F1).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.history_rounded,
                                size: 11, color: tealMid),
                            const SizedBox(width: 4),
                            Text('ARCHIVED',
                                style: GoogleFonts.outfit(
                                  fontSize: 8.5, fontWeight: FontWeight.w800,
                                  color: tealMid, letterSpacing: 0.8)),
                          ]),
                        ),
                        const Spacer(),
                        if (entry.startDate != null || entry.endDate != null)
                          _SmallDateRange(entry: entry),
                      ]),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('\u201C',
                            style: GoogleFonts.libreBaskerville(
                              fontSize: 26,
                              color: tealMid.withValues(alpha: 0.25),
                              height: 0.85,
                            )),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(entry.verse,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.libreBaskerville(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: navyColor.withValues(alpha: 0.8),
                                height: 1.5,
                              )),
                        ),
                      ]),
                      if (hasRef) ...[
                        const SizedBox(height: 6),
                        Text('— ${entry.reference}',
                            style: GoogleFonts.outfit(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: tealMid,
                            )),
                      ],
                    ],
                  ),
                ),
              ),

              // Chevron
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: tealMid.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: tealMid.withValues(alpha: 0.15)),
                  ),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 15, color: tealMid.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => CachedNetworkImage(
        imageUrl: 'https://images.unsplash.com/photo-1504052434569-70ad585e51c7?q=80&w=150&auto=format&fit=crop',
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: tealMid.withValues(alpha: 0.1),
          child: Icon(Icons.menu_book_rounded,
              size: 28, color: tealMid.withValues(alpha: 0.35)),
        ),
        errorWidget: (_, __, ___) => Container(
          color: tealMid.withValues(alpha: 0.1),
          child: Icon(Icons.menu_book_rounded,
              size: 28, color: tealMid.withValues(alpha: 0.35)),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  DETAIL SCREEN  (full-screen tap-to-view)
// ══════════════════════════════════════════════════════════════════════════════
class WordOfLifeDetailScreen extends StatefulWidget {
  final WordOfLifeEntry entry;
  const WordOfLifeDetailScreen({super.key, required this.entry});

  @override
  State<WordOfLifeDetailScreen> createState() => _WordOfLifeDetailScreenState();
}

class _WordOfLifeDetailScreenState extends State<WordOfLifeDetailScreen> {
  bool _isPlaying = false;

  static const _tealDark  = Color(0xFF0F766E);
  static const _tealMid   = Color(0xFF0D9488);
  static const _navyColor = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final hasRef       = entry.reference?.isNotEmpty == true;
    final hasReflect   = entry.reflection?.isNotEmpty == true;
    final hasAuthor    = entry.author?.isNotEmpty == true;
    final displayVideo = entry.hasVideo && _isPlaying;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFB),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero image app bar ──
            SliverAppBar(
              expandedHeight: (entry.hasImage || entry.hasVideo) ? 320 : 160,
              pinned: true,
              elevation: 0,
              backgroundColor: _tealDark,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 17),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: entry.isYoutubeVideo
                    ? GestureDetector(
                        onTap: () => _launchYoutube(entry.resolvedVideoUrl!),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildYoutubeThumbnail(
                              entry.youtubeVideoId ?? '',
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              color: Colors.black.withOpacity(0.2),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 42,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Tap to watch on YouTube',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        const Shadow(
                                          blurRadius: 10,
                                          color: Colors.black45,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : entry.hasVideo
                        ? (!_isPlaying
                            ? GestureDetector(
                                onTap: () => setState(() => _isPlaying = true),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (entry.hasImage)
                                      CachedNetworkImage(
                                        imageUrl: entry.imageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => _gradientBg(),
                                        errorWidget: (_, __, ___) => _gradientBg(),
                                      )
                                    else
                                      _gradientBg(),
                                Container(
                                  color: Colors.black.withValues(alpha: 0.25),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 68,
                                        height: 68,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D9488).withValues(alpha: 0.95),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 42,
                                        ),
                                      ),
                                      if (!entry.hasImage) ...[
                                        const SizedBox(height: 14),
                                        Text(
                                          'Tap play button to play the video',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            shadows: [
                                              const Shadow(
                                                blurRadius: 10,
                                                color: Colors.black45,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : WordOfLifeVideoPlayer(entry: entry))
                    : (entry.hasImage
                        ? GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (_, __, ___) => FullScreenImageViewer(
                                    imageUrl: entry.imageUrl!,
                                    heroTag: 'wol_detail_img_${entry.id}',
                                  ),
                                ),
                              );
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Hero(
                                  tag: 'wol_detail_img_${entry.id}',
                                  child: CachedNetworkImage(
                                    imageUrl: entry.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => _gradientBg(),
                                    errorWidget: (_, __, ___) => _gradientBg(),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.20),
                                        Colors.black.withValues(alpha: 0.55),
                                      ],
                                    ),
                                  ),
                                ),
                                // Visual Zoom Indicator
                                Positioned(
                                  bottom: 20,
                                  right: 20,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        color: Colors.black.withValues(alpha: 0.35),
                                        child: const Icon(
                                          Icons.zoom_in_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _gradientBg()),
              ),
            ),

            // ── Body content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verse card (beautiful quote format)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: _tealMid.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: _tealMid.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Large quote mark
                          Text(
                            '\u201C',
                            style: GoogleFonts.libreBaskerville(
                              fontSize: 58,
                              color: _tealMid.withValues(alpha: 0.22),
                              height: 0.6,
                            ),
                          ),
                          Text(
                            entry.verse,
                            style: GoogleFonts.libreBaskerville(
                              fontSize: 19,
                              fontStyle: FontStyle.italic,
                              color: _navyColor,
                              height: 1.7,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hasRef) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_tealDark, _tealMid],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _tealMid.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bookmark_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.reference!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (entry.hasVideo && entry.hasImage) ...[
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: entry.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _gradientBg(),
                          errorWidget: (_, __, ___) => _gradientBg(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Scripture/Reflection Section
                    if (hasReflect) ...[
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _tealMid,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Details',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _navyColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.info_outline_rounded,
                            color: _tealMid.withValues(alpha: 0.7),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final lines = entry.reflection!
                              .split('\n')
                              .where((l) => l.trim().isNotEmpty)
                              .toList();
                          final isRefList = lines.isNotEmpty &&
                              lines.every((line) => line.length < 50);

                          if (isRefList) {
                            // Render next-gen list item for each reading/reference
                            return Column(
                              children: lines.map((line) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _tealMid.withValues(alpha: 0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: _tealMid.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _tealMid.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.bookmark_outline_rounded,
                                            color: _tealMid, size: 18),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          line.trim(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            color: _navyColor,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios_rounded,
                                          size: 13,
                                          color: _tealMid.withValues(alpha: 0.4)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          } else {
                            // Render standard premium paragraph reader block
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                    color: _tealMid.withValues(alpha: 0.12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: _tealMid.withValues(alpha: 0.06),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Text(
                                entry.reflection!,
                                style: GoogleFonts.outfit(
                                  fontSize: 15.5,
                                  color: Colors.grey.shade800,
                                  height: 1.7,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Author
                    if (hasAuthor) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: _tealMid.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _tealMid.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_pin_rounded,
                                  size: 18, color: _tealMid),
                              const SizedBox(width: 8),
                              Text(
                                entry.author!,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _tealDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Date period card
                    if (entry.startDate != null || entry.endDate != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _tealDark.withValues(alpha: 0.06),
                              _tealMid.withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _tealMid.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                color: _tealMid, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              _formatPeriod(),
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _tealDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientBg() => SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: 'https://images.unsplash.com/photo-1504052434569-70ad585e51c7?q=80&w=800&auto=format&fit=crop',
          fit: BoxFit.cover,
          placeholder: (_, __) => _pureGradientBg(),
          errorWidget: (_, __, ___) => _pureGradientBg(),
        ),
      );

  Widget _pureGradientBg() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_tealDark, _tealMid, Color(0xFF14B8A6)],
          ),
        ),
      );

  String _formatPeriod() {
    final parts = <String>[];
    if (widget.entry.startDate != null) {
      parts.add(DateFormat('MMMM d, yyyy').format(widget.entry.startDate!));
    }
    if (widget.entry.endDate != null) {
      parts.add(DateFormat('MMMM d, yyyy').format(widget.entry.endDate!));
    }
    return parts.join(' → ');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════════════════
class _ActiveBadge extends StatelessWidget {
  final Animation<double>? pulse;
  const _ActiveBadge({this.pulse});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF4ADE80),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.45),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('ACTIVE',
              style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 1.0,
              )),
        ],
      ),
    );

    if (pulse == null) return badge;
    return ScaleTransition(scale: pulse!, child: badge);
  }
}

class _DateRangePill extends StatelessWidget {
  final WordOfLifeEntry entry;
  const _DateRangePill({required this.entry});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (entry.startDate != null) parts.add(DateFormat('MMM d').format(entry.startDate!));
    if (entry.endDate != null) parts.add(DateFormat('MMM d').format(entry.endDate!));
    if (parts.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range_rounded, size: 11, color: Colors.white),
              const SizedBox(width: 5),
              Text(parts.join(' – '),
                  style: GoogleFonts.outfit(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallDateRange extends StatelessWidget {
  final WordOfLifeEntry entry;
  const _SmallDateRange({required this.entry});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (entry.startDate != null) parts.add(DateFormat('MMM d').format(entry.startDate!));
    if (entry.endDate != null) parts.add(DateFormat('MMM d').format(entry.endDate!));
    return Text(parts.join(' – '),
        style: GoogleFonts.outfit(
          fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600,
        ));
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _EmptyState({required this.icon, required this.title,
      required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: color.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E3A8A),
                )),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14, color: Colors.grey.shade500, height: 1.5,
                )),
          ],
        ),
      ),
    );
  }
}
