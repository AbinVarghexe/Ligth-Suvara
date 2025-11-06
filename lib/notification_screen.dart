import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:async/async.dart';
import 'package:sundayschool_app/custom_app_bar.dart'; // ⭐️ 1. IMPORT YOUR CUSTOM APPBAR

// --- ⭐️ 2. UPDATED DATA MODEL WITH `isRead` ---
class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String recipientId;
  final bool isRead;
  final bool isFromBroadcasts;

  AppNotification.fromDoc(DocumentSnapshot doc, String currentUserId, {this.isFromBroadcasts = false})
      : id = doc.id,
        title =
            (doc.data() as Map<String, dynamic>?)?['title'] as String? ?? 'No Title',
        message =
            (doc.data() as Map<String, dynamic>?)?['body'] as String? ?? 'No Message',
        timestamp = ((doc.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?)
            ?.toDate() ??
            DateTime.now(),
        recipientId = (doc.data() as Map<String, dynamic>?)?['recipientId'] as String? ??
            'public',
        isRead = ((doc.data() as Map<String, dynamic>?)?['readBy'] as List<dynamic>? ?? [])
            .contains(currentUserId);

  // Helper to determine the type of notification for UI styling
  bool get isBroadcast => recipientId == 'all';
  bool get isPublic => isFromBroadcasts;
}

// --- MAIN SCREEN WIDGET ---
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<QuerySnapshot>> _combinedStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;

    // Define the two streams we want to listen to
    final notificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId',
        whereIn: [currentUser?.uid ?? 'INVALID_USER', 'all'])
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();

    final broadcastsStream = FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();

    _combinedStream = StreamZip([notificationsStream, broadcastsStream]);
  }

  // --- ⭐️ 3. RESTRUCTURED BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to see notifications.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // Use the shared CustomAppBar
      appBar: const CustomAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen-specific title below the AppBar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'Notifications',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          // The list of notifications fills the rest of the screen
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: _combinedStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                // MERGE, MAP, AND SORT THE RESULTS
                final notificationsDocs = snapshot.data![0].docs;
                final broadcastsDocs = snapshot.data![1].docs;

                final allDocs = [...notificationsDocs, ...broadcastsDocs];

                allDocs.sort((a, b) {
                  final aTimestamp = (a.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp? ?? Timestamp.now();
                  final bTimestamp = (b.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp? ?? Timestamp.now();
                  return bTimestamp.compareTo(aTimestamp);
                });

                if (allDocs.isEmpty) {
                  return _buildEmptyState();
                }

                final notifications = allDocs.map((doc) {
                  final isFromBroadcasts = broadcastsDocs.any((bd) => bd.id == doc.id);
                  return AppNotification.fromDoc(doc, currentUser.uid, isFromBroadcasts: isFromBroadcasts);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _ModernNotificationTile(notification: notification);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text("You're all caught up!", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("New notifications will appear here.", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// --- ⭐️ 4. MODERNIZED NOTIFICATION TILE (NOW STATEFUL) ---
class _ModernNotificationTile extends StatefulWidget {
  final AppNotification notification;

  const _ModernNotificationTile({required this.notification});

  @override
  State<_ModernNotificationTile> createState() => _ModernNotificationTileState();
}

class _ModernNotificationTileState extends State<_ModernNotificationTile> {
  // ⭐️ ADD A LOCAL STATE VARIABLE FOR isRead
  late bool _isUnread;

  @override
  void initState() {
    super.initState();
    // Initialize the local state from the widget's data
    _isUnread = !widget.notification.isRead;
  }

  // Helper methods can remain the same
  String getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 60) return "Just now";
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return DateFormat('d MMM, yyyy').format(timestamp);
  }

  _TileStyle _getStyle() {
    if (widget.notification.isPublic) {
      return _TileStyle(icon: Icons.public, color: Colors.green);
    }
    if (widget.notification.isBroadcast) {
      return _TileStyle(icon: Icons.campaign_rounded, color: Colors.orange);
    }
    return _TileStyle(icon: Icons.person_rounded, color: Colors.blue);
  }

  // --- ⭐️ 5. MARK AS READ FUNCTIONALITY (NOW UPDATES LOCAL STATE) ---
  void _markAsReadAndShowDialog(BuildContext context, _TileStyle style) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_isUnread) {
      final collection = widget.notification.isFromBroadcasts ? 'broadcasts' : 'notifications';
      FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.notification.id)
          .update({
        'readBy': FieldValue.arrayUnion([currentUser.uid])
      }).catchError((e) => print("Error updating notification: $e"));

      setState(() {
        _isUnread = false;
      });
    }
    _showNotificationDialog(context, style);
  }

  // The _showNotificationDialog method remains exactly the same as before
  void _showNotificationDialog(BuildContext context, _TileStyle style) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close",
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: style.color.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(style.icon,
                            color: style.color.shade800, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.notification.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            widget.notification.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.black54,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            "Close",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: anim1.drive(CurveTween(curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle();
    // ⭐️ USE THE LOCAL STATE VARIABLE `_isUnread` FOR STYLING
    final cardColor = _isUnread ? style.color.shade50 : Colors.white;
    final titleColor = _isUnread ? Colors.black87 : Colors.grey.shade700;
    final titleWeight = _isUnread ? FontWeight.w700 : FontWeight.w500;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: _isUnread ? 2.0 : 0.5,
      shadowColor: Colors.black.withAlpha(20),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _isUnread
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _markAsReadAndShowDialog(context, style),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with unread indicator
              SizedBox(
                width: 45,
                height: 45,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: style.color.withOpacity(_isUnread ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          style.icon,
                          color: style.color.shade800.withOpacity(_isUnread ? 1.0 : 0.7),
                          size: 24,
                        ),
                      ),
                    ),
                    if (_isUnread)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Title, Message, and Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.notification.title,
                      style: GoogleFonts.poppins(
                        fontWeight: titleWeight,
                        fontSize: 15,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.notification.message,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black.withOpacity(_isUnread ? 0.6 : 0.4),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      getTimeAgo(widget.notification.timestamp),
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
}


// A simple helper class for styling
class _TileStyle {
  final IconData icon;
  final MaterialColor color;
  _TileStyle({required this.icon, required this.color});
}
