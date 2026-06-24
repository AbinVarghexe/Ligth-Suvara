// lib/catechism_hour_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:sundayschool_app/providers/catechism_hour_provider.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';

class CatechismHourScreen extends StatefulWidget {
  const CatechismHourScreen({super.key});

  @override
  State<CatechismHourScreen> createState() => _CatechismHourScreenState();
}

class _CatechismHourScreenState extends State<CatechismHourScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;

  static const _navyColor = Color(0xFF1E3A8A);
  static const _indigoColor = Color(0xFF6366F1);
  static const _indigoDark = Color(0xFF4338CA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
      backgroundColor: const Color(0xFFF1F4FF),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: FadeTransition(
          opacity: _fadeController,
          child: Consumer<CatechismHourProvider>(
            builder: (context, provider, _) {
              final activeEntries = provider.entries
                  .where((e) => e.isActive)
                  .toList();
              final historyEntries = provider.entries
                  .where((e) => e.isPast)
                  .toList();

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  _buildSliverAppBar(
                    innerBoxIsScrolled,
                    hasHistory: historyEntries.isNotEmpty,
                  ),
                ],
                body: provider.isLoading
                    ? _buildShimmer()
                    : provider.error != null
                    ? _buildErrorState(provider)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 0 – Active
                          _buildActiveTab(activeEntries),
                          // Tab 1 – History
                          _buildHistoryTab(historyEntries),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── APP BAR ────────────────────────────

  Widget _buildSliverAppBar(
    bool innerBoxIsScrolled, {
    required bool hasHistory,
  }) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      floating: false,
      forceElevated: innerBoxIsScrolled,
      elevation: 0,
      backgroundColor: _indigoDark,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 17,
            ),
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
            Text(
              'വിശ്വാസ പരിശീലന മണിക്കൂർ',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            Text(
              'Catechetical Hour',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        background: _buildAppBarBackground(),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
        tabs: [
          const Tab(text: 'Today'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('History'),
                if (hasHistory) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF4338CA), Color(0xFF6366F1)],
            ),
          ),
        ),
        // Decorative watermark
        Positioned(
          right: -30,
          top: -20,
          child: Opacity(
            opacity: 0.08,
            child: Icon(Icons.church_rounded, size: 200, color: Colors.white),
          ),
        ),
        // Shimmer wave effect
        Positioned(
          left: 0,
          bottom: 52,
          right: 0,
          child: Opacity(
            opacity: 0.06,
            child: Image.asset(
              'assets/images/diocese.png',
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        // Bottom fade
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── ACTIVE TAB ──────────────────────────

  Widget _buildActiveTab(List<CatechismHourEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.upcoming_rounded,
        title: 'No Upcoming Sessions',
        subtitle:
            'When a new Catechetical Hour is scheduled, it will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<CatechismHourProvider>().refresh(),
      color: _indigoColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) =>
            _buildActiveCard(entries[index], isFirst: index == 0),
      ),
    );
  }

  Widget _buildActiveCard(CatechismHourEntry entry, {bool isFirst = false}) {
    final hasImage = entry.imageUrl != null && entry.imageUrl!.isNotEmpty;
    final hasNotes = entry.notes != null && entry.notes!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) =>
                CatechismHourDetailScreen(entry: entry),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: isFirst ? 20 : 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: isFirst
                ? Border.all(
                    color: _indigoColor.withValues(alpha: 0.35),
                    width: 2,
                  )
                : Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: isFirst
                    ? _indigoColor.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isFirst ? 30 : 12,
                offset: Offset(0, isFirst ? 12 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero image with overlaid gradient ──
              if (hasImage)
                _buildHeroImage(entry, isFirst: isFirst)
              else
                _buildColoredHeader(entry, isFirst: isFirst),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      entry.title,
                      style: GoogleFonts.outfit(
                        fontSize: isFirst ? 22 : 18,
                        fontWeight: FontWeight.w800,
                        color: _navyColor,
                        height: 1.25,
                      ),
                    ),

                    // Notes / description
                    if (hasNotes) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _indigoColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _indigoColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _indigoColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notes_rounded,
                                color: _indigoColor,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.notes!,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                  height: 1.55,
                                ),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildHeroImage(CatechismHourEntry entry, {required bool isFirst}) {
    final hasNotes = entry.notes != null && entry.notes!.isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Stack(
        children: [
          // Black background so contain-fit has no whitespace
          Container(
            height: isFirst ? 240 : 180,
            width: double.infinity,
            color: Colors.black,
          ),
          // Image
          CachedNetworkImage(
            imageUrl: entry.imageUrl!,
            height: isFirst ? 240 : 180,
            width: double.infinity,
            fit: BoxFit.contain,
            placeholder: (_, __) => Container(
              height: isFirst ? 240 : 180,
              color: _indigoColor.withValues(alpha: 0.08),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: isFirst ? 240 : 180,
              color: _indigoColor.withValues(alpha: 0.08),
              child: Icon(
                Icons.church_rounded,
                size: 48,
                color: _indigoColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Date pill (top-left)
          if (entry.date != null)
            Positioned(
              top: 12,
              left: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEE, MMM d').format(entry.date!),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Active badge (top-right)
          if (isFirst)
            Positioned(
              top: 12,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ACTIVE',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Title on image
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, hasNotes ? 0 : 16),
              child: Text(
                entry.title,
                style: GoogleFonts.outfit(
                  fontSize: isFirst ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColoredHeader(
    CatechismHourEntry entry, {
    required bool isFirst,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isFirst
              ? [_indigoDark, _indigoColor]
              : [
                  _indigoColor.withValues(alpha: 0.8),
                  _indigoColor.withValues(alpha: 0.6),
                ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirst)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'ACTIVE',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                Icon(
                  Icons.church_rounded,
                  size: 36,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
          if (entry.date != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(entry.date!),
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(entry.date!).toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────── HISTORY TAB ─────────────────────────

  Widget _buildHistoryTab(List<CatechismHourEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'No History Yet',
        subtitle: 'Past Catechetical Hour sessions will be archived here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<CatechismHourProvider>().refresh(),
      color: _indigoColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) => _buildHistoryCard(entries[index]),
      ),
    );
  }

  Widget _buildHistoryCard(CatechismHourEntry entry) {
    final hasImage = entry.imageUrl != null && entry.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) =>
                CatechismHourDetailScreen(entry: entry),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: entry.imageUrl!,
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            _historyThumb(color: Colors.grey.shade100),
                        errorWidget: (_, __, ___) =>
                            _historyThumb(showIcon: true),
                      )
                    : _historyThumb(showIcon: true),
              ),
              // Text content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.date != null)
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(entry.date!),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: _indigoColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _navyColor,
                          height: 1.3,
                        ),
                      ),
                      if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyThumb({Color? color, bool showIcon = false}) {
    return Container(
      width: 86,
      height: 86,
      color: color ?? _indigoColor.withValues(alpha: 0.07),
      child: showIcon
          ? Icon(
              Icons.church_rounded,
              color: _indigoColor.withValues(alpha: 0.3),
              size: 30,
            )
          : null,
    );
  }

  // ─────────────────────────── STATES ──────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            ...List.generate(
              2,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _indigoColor.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 52,
                color: _indigoColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _navyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(CatechismHourProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load sessions',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _navyColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigoColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DETAIL SCREEN (tap-to-view detail for Catechetical Hour)
// ══════════════════════════════════════════════════════════════════════════════
class CatechismHourDetailScreen extends StatelessWidget {
  final CatechismHourEntry entry;
  const CatechismHourDetailScreen({super.key, required this.entry});

  static const _navyColor = Color(0xFF1E3A8A);
  static const _indigoColor = Color(0xFF6366F1);
  static const _indigoDark = Color(0xFF4338CA);

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.imageUrl?.isNotEmpty == true;
    final hasNotes = entry.notes?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4FF),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero image app bar ──
            SliverAppBar(
              expandedHeight: hasImage
                  ? MediaQuery.of(context).size.height * 0.75
                  : 150,
              pinned: true,
              elevation: 0,
              backgroundColor: _indigoDark,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: hasImage
                    ? GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (_, __, ___) =>
                                  FullScreenImageViewer(
                                    imageUrl: entry.imageUrl!,
                                    heroTag: 'catechism_detail_img_${entry.id}',
                                  ),
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Black background so contain-fit has no whitespace
                            Container(color: Colors.black),
                            Hero(
                              tag: 'catechism_detail_img_${entry.id}',
                              child: CachedNetworkImage(
                                imageUrl: entry.imageUrl!,
                                fit: BoxFit.contain, // full image, no cropping
                                placeholder: (_, __) => _gradientBg(),
                                errorWidget: (_, __, ___) => _gradientBg(),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _gradientBg(),
              ),
            ),

            // ── Body content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _indigoColor.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: _indigoColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        entry.title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _navyColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Details/Notes
                    if (hasNotes) ...[
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _indigoColor,
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
                            color: _indigoColor.withValues(alpha: 0.7),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _indigoColor.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _indigoColor.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          entry.notes!,
                          style: GoogleFonts.outfit(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            height: 1.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Session Date
                    if (entry.date != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _indigoDark.withValues(alpha: 0.06),
                              _indigoColor.withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _indigoColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              color: _indigoColor,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(entry.date!),
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _indigoDark,
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

  Widget _gradientBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_indigoDark, _indigoColor, Color(0xFF6366F1)],
      ),
    ),
  );
}
