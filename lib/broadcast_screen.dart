// lib/broadcast_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';
import 'package:provider/provider.dart';
import 'package:sundayschool_app/providers/content_provider.dart';

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
    'color': Colors.blue.shade400,
    'gradient': LinearGradient(
      colors: [Colors.blue.shade400, Colors.blue.shade600],
    ),
  };
}

class BroadcastDetailScreen extends StatelessWidget {
  final BroadcastMessage message;

  const BroadcastDetailScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: message.imageUrl != null ? 300 : 120,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue.shade900,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
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
                            child: Image.network(
                              message.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: iconData['gradient'] as LinearGradient?,
                          ),
                          child: Hero(
                            tag: 'broadcast_icon_${message.id}',
                            child: Center(
                              child: Icon(
                                iconData['icon'] as IconData?,
                                color: Colors.white.withOpacity(0.2),
                                size: 80,
                              ),
                            ),
                          ),
                        );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(message.timestamp),
                          style: GoogleFonts.poppins(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message.title,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(
                    message.body,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      height: 1.7,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: FloatingActionButton.small(
          onPressed: () => Navigator.of(context).pop(),
          backgroundColor: Colors.black.withOpacity(0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.close_rounded),
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
        top: 28.0,
        bottom: 12.0,
        right: 20.0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade900, Colors.blue.shade700],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade900.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              margin: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade300,
                    Colors.grey.shade300.withOpacity(0),
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
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.blue[900],
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 1.0],
                colors: [Color(0xFFFFFAF0), Color(0xFFFFF8E1)],
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('broadcasts')
                  .orderBy('timestamp', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                final provider = Provider.of<ContentProvider>(
                  context,
                  listen: false,
                );
                final bool hasCachedData = provider.broadcasts.isNotEmpty;

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !hasCachedData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade900,
                      ),
                    ),
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

                for (int i = 0; i < messages.length; i++) {
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
                          vertical: 6.0,
                        ),
                        child: CustomBroadcastTile(message: message, index: i),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  physics: const BouncingScrollPhysics(),
                  children: timelineWidgets,
                );
              },
            ),
          ),
        ],
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
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? iconData['color'].withOpacity(0.3)
              : const Color(0xFFFFE4B5).withOpacity(0.4),
          width: isHighlighted ? 2 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BroadcastDetailScreen(message: message),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: message.imageUrl != null
                      ? 'broadcast_image_${message.id}'
                      : 'broadcast_icon_${message.id}',
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: message.imageUrl == null
                          ? iconData['gradient']
                          : null,
                      color: message.imageUrl != null
                          ? Colors.grey.shade200
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: iconData['color'].withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: message.imageUrl != null
                          ? Image.network(
                              message.imageUrl!,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                            )
                          : Center(
                              child: Icon(
                                iconData['icon'],
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[900],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeAgo(message.timestamp),
                            style: GoogleFonts.poppins(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey[400],
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
