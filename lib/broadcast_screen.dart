// lib/broadcast_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// A simple model for our broadcast messages
class BroadcastMessage {
  final String title;
  final String body;
  final DateTime timestamp;
  final String? imageUrl; // NEW: Added imageUrl

  BroadcastMessage.fromDoc(DocumentSnapshot doc)
    : title = (doc.data() as Map<String, dynamic>?)?['title'] ?? 'No Title',
      body = (doc.data() as Map<String, dynamic>?)?['body'] ?? 'No Body',
      timestamp =
          ((doc.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?)
              ?.toDate() ??
          DateTime.now(),
      imageUrl = (doc.data() as Map<String, dynamic>?)?['imageUrl'];

  // Constructor for manual creation (e.g. from LoginScreen)
  BroadcastMessage({
    required this.title,
    required this.body,
    required this.timestamp,
    this.imageUrl,
  });
}

// Helper method to determine icon/color - Made public for reuse consistency if needed,
// strictly speaking we have a localized version in LoginScreen too.
// We'll keep the logic inside the dialog/tile for now.

// --- PUBLIC DIALOG FUNCTION ---
void showBroadcastDetailDialog(BuildContext context, BroadcastMessage message) {
  // We need to re-derive icon data here since we are just passing the message
  final iconData = _getIconDataGlobal(message.title);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(
          opacity: animation,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 60.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.0),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height *
                    0.85, // Increased height for image
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header (Image or Gradient)
                  if (message.imageUrl != null)
                    Stack(
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            image: DecorationImage(
                              image: NetworkImage(message.imageUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Gradient overlay for text readability if we put text on top,
                        // but here we have text below. Let's add a neat close button or drag handle on top.
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: iconData['gradient'],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              iconData['icon'],
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Title & Meta Section
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      children: [
                        Text(
                          message.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.blue.shade800,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  'MMM d, yyyy • h:mm a',
                                ).format(message.timestamp),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Area
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.body,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.grey[700],
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Close Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconData['color'], // Theme color
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
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Internal Helper for Icon Data (Duplicated logic for standalone function usage)
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

  // Helper method to create date headers like "Today", "Yesterday", or "15 October, 2023"
  String _getTimelineHeader(DateTime timestamp) {
    final now = DateTime.now();
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('d MMMM, yyyy').format(timestamp);
    }
  }

  // Helper widget for the styled date headers
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade200, Colors.grey.shade100],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Gradient Background Layer
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 1.0],
                colors: [
                  Color(0xFFFFFAF0), // Very Soft Cream (Floral White)
                  Color(0xFFFFF8E1), // Ultra Light Gold
                ],
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade900,
                          ),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading updates...',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: Colors.blue.shade300,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "No recent updates found",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Check back later for new announcements",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs
                    .map((doc) => BroadcastMessage.fromDoc(doc))
                    .toList();

                // Timeline Processing Logic
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

// Custom Tile Widget for displaying each broadcast message
class CustomBroadcastTile extends StatelessWidget {
  final BroadcastMessage message;
  final int index;

  const CustomBroadcastTile({
    super.key,
    required this.message,
    required this.index,
  });

  // Helper to format the timestamp
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
    final iconData = _getIconDataGlobal(message.title); // Use global helper
    final bool isHighlighted =
        message.title.toLowerCase().contains('kalolsavam') ||
        message.title.toLowerCase().contains('important');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8), // Cream background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? iconData['color'].withOpacity(0.3)
              : const Color(0xFFFFE4B5).withOpacity(0.4), // Soft gold border
          width: isHighlighted ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.08), // Warm shadow
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showBroadcastDetailDialog(
            context,
            message,
          ), // Use public function
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon / Image
                Container(
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
                    image: message.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(message.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: iconData['color'].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: message.imageUrl == null
                      ? Icon(iconData['icon'], color: Colors.white, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[900],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isHighlighted)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: iconData['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: iconData['color'],
                              ),
                            ),
                        ],
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
                              fontWeight: FontWeight.w500,
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
