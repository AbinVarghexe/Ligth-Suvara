// lib/broadcast_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';
import 'package:provider/provider.dart';
import 'package:sundayschool_app/providers/content_provider.dart';
import 'package:sundayschool_app/widgets/heavenly_background.dart';
import 'package:sundayschool_app/widgets/linkable_text.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Brand colors for consistency
const Color _primaryBlue = Color(0xFF1E3A8A);
const Color _goldAccent = Color(0xFFBC8A3A);

// A simple model for our broadcast messages
class BroadcastMessage {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? imageUrl;

  BroadcastMessage.fromDoc(DocumentSnapshot doc)
    : id = doc.id,
      title = (doc.data() as Map<String, dynamic>?)?['title'] ?? 'No Title',
      body = (doc.data() as Map<String, dynamic>?)?['body'] ?? 'No Body',
      timestamp =
          ((doc.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?)
              ?.toDate() ??
          DateTime.now(),
      imageUrl = (doc.data() as Map<String, dynamic>?)?['imageUrl'];

  BroadcastMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.imageUrl,
  });
}

// Global helper for icons
Map<String, dynamic> _getIconDataGlobal(String title) {
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
    'color': _primaryBlue,
    'gradient': LinearGradient(
      colors: [_primaryBlue, Colors.blue.shade700],
    ),
  };
}

class BroadcastDetailScreen extends StatelessWidget {
  final BroadcastMessage message;

  const BroadcastDetailScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HeavenlyBackground(
        showImage: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: message.imageUrl != null ? 350 : 150,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _primaryBlue),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Builder(
                  builder: (context) {
                    final iconData = _getIconDataGlobal(message.title);
                    return message.imageUrl != null
                        ? GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageViewer(
                                    imageUrl: message.imageUrl!,
                                    heroTag: 'broadcast_image_${message.id}',
                                  ),
                                ),
                              );
                            },
                            child: Hero(
                              tag: 'broadcast_image_${message.id}',
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: message.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: Colors.grey.shade300,
                                      highlightColor: Colors.grey.shade100,
                                      child: Container(
                                        color: Colors.white,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.4),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_primaryBlue.withOpacity(0.8), _primaryBlue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                iconData['icon'] as IconData?,
                                color: Colors.white.withOpacity(0.3),
                                size: 100,
                              ),
                            ),
                          );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB).withOpacity(0.7), // Warm Tinted Glass
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _goldAccent.withOpacity(0.1),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _primaryBlue.withOpacity(0.1)),
                        ),
                        child: Text(
                          DateFormat('MMMM d, yyyy').format(message.timestamp),
                          style: GoogleFonts.outfit(
                            color: _primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        message.title,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _primaryBlue,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 24),
                      LinkableText(
                        message.body,
                        linkColor: _primaryBlue,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          height: 1.6,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: _primaryBlue.withOpacity(0.4),
                          ),
                          child: Text(
                            'Got It',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _limit = 6;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getTimelineHeader(DateTime timestamp) {
    final now = DateTime.now();
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.isAtSameMomentAs(today)) return 'Today';
    if (date.isAtSameMomentAs(yesterday)) return 'Yesterday';
    return DateFormat('d MMMM, yyyy').format(timestamp);
  }

  Widget _buildTimelineHeaderWidget(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20.0,
        top: 32.0,
        bottom: 12.0,
        right: 20.0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB).withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _goldAccent.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _goldAccent.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: _goldAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _goldAccent.withOpacity(0.3),
                    _goldAccent.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Recent Updates',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: _primaryBlue,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryBlue,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: HeavenlyBackground(
        showImage: true,
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('broadcasts')
                .orderBy('timestamp', descending: true)
                .limit(_limit + 1)
                .snapshots(),
            builder: (context, snapshot) {
              final provider = Provider.of<ContentProvider>(
                context,
                listen: false,
              );
              final bool hasCachedData = provider.broadcasts.isNotEmpty;

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !hasCachedData) {
                return const Center(
                  child: CircularProgressIndicator(color: _primaryBlue),
                );
              }

              final List<BroadcastMessage> messages;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                messages = snapshot.data!.docs
                    .map((doc) => BroadcastMessage.fromDoc(doc))
                    .toList();
              } else if (hasCachedData) {
                messages = provider.broadcasts
                    .map((doc) => BroadcastMessage.fromDoc(doc))
                    .toList();
              } else {
                return const Center(child: Text("No updates found"));
              }

              final List<Widget> timelineWidgets = [];
              String? lastHeader = '';

              final int displayCount = messages.length > _limit ? _limit : messages.length;
              final bool hasMore = messages.length > _limit;

              for (int i = 0; i < displayCount; i++) {
                var message = messages[i];
                String currentHeader = _getTimelineHeader(message.timestamp);

                if (currentHeader != lastHeader) {
                  timelineWidgets.add(
                    _buildTimelineHeaderWidget(currentHeader),
                  );
                  lastHeader = currentHeader;
                }

                timelineWidgets.add(
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: CustomBroadcastTile(message: message, index: i),
                    ),
                  ),
                );
              }

              if (hasMore) {
                timelineWidgets.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 24.0,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _goldAccent.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _limit += 6;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _goldAccent, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.8),
                        ),
                        child: Text(
                          'View More',
                          style: GoogleFonts.outfit(
                            color: _primaryBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 40, top: 8),
                physics: const BouncingScrollPhysics(),
                children: timelineWidgets,
              );
            },
          ),
        ),
      ),
    );
  }
}

class CustomBroadcastTile extends StatelessWidget {
  final BroadcastMessage message;
  final int index;

  const CustomBroadcastTile({
    super.key,
    required this.message,
    required this.index,
  });

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconDataGlobal(message.title);
    final bool isHighlighted =
        message.title.toLowerCase().contains('kalolsavam') ||
        message.title.toLowerCase().contains('important');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withOpacity(0.55), // Warm Glass Tint
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isHighlighted
              ? iconData['color'].withOpacity(0.5)
              : const Color(0xFFD4AF37).withOpacity(0.35),
          width: isHighlighted ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? iconData['color'] : _goldAccent).withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BroadcastDetailScreen(message: message),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: message.imageUrl != null
                      ? 'broadcast_image_${message.id}'
                      : 'broadcast_icon_${message.id}',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: message.imageUrl == null
                          ? iconData['gradient']
                          : null,
                      color: message.imageUrl != null
                          ? Colors.grey.shade200
                          : null,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        if (message.imageUrl == null)
                          BoxShadow(
                            color: iconData['color'].withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: message.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: message.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  color: Colors.white,
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                iconData['icon'],
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: _primaryBlue,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_filled_rounded,
                            size: 14,
                            color: _goldAccent.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getTimeAgo(message.timestamp),
                            style: GoogleFonts.outfit(
                              color: _goldAccent.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: _primaryBlue,
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
      ),
    );
  }
}

