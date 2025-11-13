import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:async/async.dart';
import 'package:shimmer/shimmer.dart';

// --- DATA MODEL ---
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
        title = (doc.data() as Map<String, dynamic>?)?['title'] as String? ?? 'No Title',
        message = (doc.data() as Map<String, dynamic>?)?['body'] as String? ?? 'No Message',
        timestamp = ((doc.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        recipientId = (doc.data() as Map<String, dynamic>?)?['recipientId'] as String? ?? 'public',
        isRead = ((doc.data() as Map<String, dynamic>?)?['readBy'] as List<dynamic>? ?? []).contains(currentUserId);

  bool get isBroadcast => recipientId == 'all';
  bool get isPublic => isFromBroadcasts;
}

// --- MAIN SCREEN ---
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with TickerProviderStateMixin {
  late final Stream<List<QuerySnapshot>> _combinedStream;
  late AnimationController _headerController;
  late AnimationController _fabController;
  late Animation<double> _headerAnimation;
  late Animation<Offset> _headerSlide;
  late Animation<double> _fabAnimation;

  int _selectedFilter = 0; // 0: All, 1: Unread, 2: Read
  final List<String> _filters = ['All', 'Unread', 'Read'];

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;

    final notificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', whereIn: [currentUser?.uid ?? 'INVALID_USER', 'all'])
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();

    final broadcastsStream = FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();

    _combinedStream = StreamZip([notificationsStream, broadcastsStream]);

    // Header animation
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _headerAnimation = CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    // FAB animation
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabAnimation = CurvedAnimation(parent: _fabController, curve: Curves.elasticOut);

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fabController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Mark All as Read', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Mark all notifications as read?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Confirm', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final notificationsSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', whereIn: [user.uid, 'all'])
          .get();

      final broadcastsSnap = await FirebaseFirestore.instance
          .collection('broadcasts')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in notificationsSnap.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([user.uid])
        });
      }

      for (var doc in broadcastsSnap.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([user.uid])
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All notifications marked as read', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text('Notifications', style: GoogleFonts.poppins(color: const Color(0xFF1E40AF))),
        ),
        body: const Center(child: Text('Please log in to see notifications.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E40AF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: const Color(0xFF1E40AF),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Animated Header Section
          SlideTransition(
            position: _headerSlide,
            child: FadeTransition(
              opacity: _headerAnimation,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1E40AF), Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.notifications_active, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stay Updated',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'All your important updates in one place',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
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

          // Modern Filter Tabs
          _buildFilterTabs(),

          // Notification List
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: _combinedStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingSkeleton();
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

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

                var notifications = allDocs.map((doc) {
                  final isFromBroadcasts = broadcastsDocs.any((bd) => bd.id == doc.id);
                  return AppNotification.fromDoc(doc, currentUser.uid, isFromBroadcasts: isFromBroadcasts);
                }).toList();

                // Apply filter
                if (_selectedFilter == 1) {
                  notifications = notifications.where((n) => !n.isRead).toList();
                } else if (_selectedFilter == 2) {
                  notifications = notifications.where((n) => n.isRead).toList();
                }

                if (notifications.isEmpty) {
                  return _buildEmptyState(filterApplied: true);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 400 + (index * 80)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(50 * (1 - value), 0),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: _ModernNotificationTile(notification: notifications[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: _markAllAsRead,
          backgroundColor: const Color(0xFF1E40AF),
          icon: const Icon(Icons.done_all, color: Colors.white),
          label: Text('Mark All Read', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(
              _selectedFilter == 0 ? -1.0 : (_selectedFilter == 1 ? 0.0 : 1.0),
              0,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              width: (MediaQuery.of(context).size.width - 32) / 3,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: List.generate(_filters.length, (index) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedFilter = index);
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Text(
                        _filters[index],
                        style: GoogleFonts.poppins(
                          color: _selectedFilter == index ? Colors.white : const Color(0xFF1E40AF),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: double.infinity, color: Colors.black, margin: const EdgeInsets.only(bottom: 8)),
                      Container(height: 12, width: 200, color: Colors.black),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({bool filterApplied = false}) {
    return Center(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: Opacity(opacity: value, child: child));
        },
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  filterApplied ? Icons.filter_list_off : Icons.notifications_off_outlined,
                  size: 70,
                  color: const Color(0xFF1E40AF).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                filterApplied ? 'No notifications here' : "You're all caught up!",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E40AF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                filterApplied
                    ? 'Try changing the filter above'
                    : 'New notifications will appear here',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NOTIFICATION TILE ---
class _ModernNotificationTile extends StatefulWidget {
  final AppNotification notification;

  const _ModernNotificationTile({required this.notification});

  @override
  State<_ModernNotificationTile> createState() => _ModernNotificationTileState();
}

class _ModernNotificationTileState extends State<_ModernNotificationTile> with SingleTickerProviderStateMixin {
  late bool _isUnread;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _isUnread = !widget.notification.isRead;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (_isUnread) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 60) return "Just now";
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return DateFormat('d MMM').format(timestamp);
  }

  _TileStyle _getStyle() {
    if (widget.notification.isPublic) {
      return _TileStyle(
        icon: Icons.public_rounded,
        color: Colors.green.shade700,
        lightColor: Colors.green.shade100,
      );
    }
    if (widget.notification.isBroadcast) {
      return _TileStyle(
        icon: Icons.campaign_rounded,
        color: Colors.orange.shade700,
        lightColor: Colors.orange.shade100,
      );
    }
    return _TileStyle(
      icon: Icons.person_rounded,
      color: const Color(0xFF1E40AF),
      lightColor: Colors.blue.shade100,
    );
  }

  void _markAsReadAndShowDialog(BuildContext context, _TileStyle style) {
    HapticFeedback.lightImpact();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (_isUnread) {
      final collection = widget.notification.isFromBroadcasts ? 'broadcasts' : 'notifications';
      FirebaseFirestore.instance.collection(collection).doc(widget.notification.id).update({
        'readBy': FieldValue.arrayUnion([currentUser.uid])
      }).catchError((e) => debugPrint("Error: $e"));

      setState(() {
        _isUnread = false;
        _glowController.stop();
      });
    }
    _showNotificationDialog(context, style);
  }

  void _showNotificationDialog(BuildContext context, _TileStyle style) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close",
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: style.color.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: style.lightColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: style.color.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(style.icon, color: style.color, size: 36),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.notification.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            widget.notification.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                          child: Text('Got it', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
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
          scale: anim1.drive(CurveTween(curve: Curves.easeOutBack)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle();

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _isUnread ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _isUnread ? const Color(0xFF1E40AF).withOpacity(0.3) : Colors.grey.shade200,
              width: _isUnread ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isUnread
                    ? const Color(0xFF1E40AF).withOpacity(_glowAnimation.value * 0.3)
                    : Colors.black.withOpacity(0.03),
                blurRadius: _isUnread ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _markAsReadAndShowDialog(context, style),
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: style.lightColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(style.icon, color: style.color, size: 26),
                        ),
                        if (_isUnread)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E40AF),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.notification.title,
                            style: GoogleFonts.poppins(
                              fontWeight: _isUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 15,
                              color: _isUnread ? const Color(0xFF1E40AF) : Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.notification.message,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: style.color.withOpacity(0.7)),
                              const SizedBox(width: 4),
                              Text(
                                getTimeAgo(widget.notification.timestamp),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: style.color.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: _isUnread ? const Color(0xFF1E40AF).withOpacity(0.5) : Colors.grey.shade400,
                      size: 22,
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
}

class _TileStyle {
  final IconData icon;
  final Color color;
  final Color lightColor;

  _TileStyle({required this.icon, required this.color, required this.lightColor});
}