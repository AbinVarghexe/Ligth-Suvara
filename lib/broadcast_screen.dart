// lib/broadcast_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// A simple model for our broadcast messages
class BroadcastMessage {
  final String title;
  final String body;
  final DateTime timestamp;

  BroadcastMessage.fromDoc(DocumentSnapshot doc)
      : title = (doc.data() as Map<String, dynamic>?)?['title'] ?? 'No Title',
        body = (doc.data() as Map<String, dynamic>?)?['body'] ?? 'No Body',
        timestamp = ((doc.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
}

class BroadcastScreen extends StatelessWidget {
  const BroadcastScreen({super.key});

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
      padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0, right: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Recent Updates', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue[900]),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // --- CORRECTED QUERY ---
        // This now points to the 'broadcasts' collection to show only public messages.
        stream: FirebaseFirestore.instance
            .collection('broadcasts')
            .orderBy('timestamp', descending: true)
            .limit(30) // Increased limit slightly
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No recent updates found.", style: TextStyle(color: Colors.grey)));
          }

          final messages = snapshot.data!.docs.map((doc) => BroadcastMessage.fromDoc(doc)).toList();

          // --- Timeline Processing Logic ---
          final List<Widget> timelineWidgets = [];
          String? lastHeader = '';

          for (var message in messages) {
            String currentHeader = _getTimelineHeader(message.timestamp);
            if (currentHeader != lastHeader) {
              timelineWidgets.add(_buildTimelineHeaderWidget(currentHeader));
              lastHeader = currentHeader;
            }

            // Wrap the custom tile in Padding for better spacing between cards
            timelineWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: CustomBroadcastTile(message: message),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 20), // Padding at the bottom of the list
            children: timelineWidgets,
          );
        },
      ),
    );
  }
}

// Custom Tile Widget for displaying each broadcast message
class CustomBroadcastTile extends StatelessWidget {
  final BroadcastMessage message;
  const CustomBroadcastTile({super.key, required this.message});

  // Helper to determine the icon based on the message title
  IconData _getIcon(String title) {
    if (title.toLowerCase().contains('lifeline') || title.toLowerCase().contains('kalolsavam')) {
      return Icons.calendar_today_outlined;
    } else if (title.toLowerCase().contains('rally')) {
      return Icons.article_outlined;
    }
    return Icons.campaign;
  }

  // Helper to format the timestamp into a short "time ago" format
  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inHours < 1) return '${difference.inMinutes} M';
    if (difference.inDays == 0) return '${difference.inHours} H';
    return DateFormat('d MMM').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = message.title.toLowerCase().contains('kalolsavam');

    // Using a Card for a clean, elevated look
    return Card(
      elevation: 2.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: isHighlighted ? Colors.blue.shade50 : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_getIcon(message.title), color: Colors.blue, size: 24),
        ),
        title: Text(
          message.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            message.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4),
          ),
        ),
        trailing: Text(
          _getTimeAgo(message.timestamp),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        // lib/broadcast_screen.dart

// ... inside the CustomBroadcastTile widget ...

        // lib/broadcast_screen.dart

// ... inside the CustomBroadcastTile widget ...

        onTap: () {
          // --- NEW, ADAPTIVE & MODERN DIALOG ---
          showDialog(
            context: context,
            // Use a barrier color for a nice dimming effect
            barrierColor: Colors.black.withOpacity(0.5),
            builder: (context) {
              return Dialog(
                // Position the dialog with some vertical margin
                insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                elevation: 0, // We will use a container shadow instead
                backgroundColor: Colors.transparent, // Make dialog background transparent
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Crucial for adaptive height
                    children: [
                      // A small grip handle for modern UI feel
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // --- Main Content Area ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Icon and Title
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIcon(message.title),
                                  color: Colors.blue.shade700,
                                  size: 28,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    message.title,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: Colors.grey.shade200, height: 1),
                            const SizedBox(height: 16),

                            // 2. ADAPTIVE Scrollable Body Content
                            Flexible(
                              child: SingleChildScrollView(
                                child: Text(
                                  message.body,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[850],
                                    height: 1.6, // More generous line spacing
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 3. Styled Close Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0, // Flat design for the button
                                ),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
          );
        },
      ),
    );
  }
}
