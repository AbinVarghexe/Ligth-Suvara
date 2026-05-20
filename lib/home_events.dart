import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sundayschool_app/event_detail_screen_from_home.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/widgets/heavenly_background.dart';
import 'package:shimmer/shimmer.dart';

class HomeEventsScreen extends StatelessWidget {
  const HomeEventsScreen({super.key});

  // Defines the primary brand colors for consistency
  static const Color _primaryBlue = Color(0xFF1E3A8A); // Deep Royal Blue
  static const Color _goldAccent = Color(0xFFBC8A3A); // Gold Accent

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _primaryBlue,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Events',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: _primaryBlue,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: HeavenlyBackground(
        showImage: true,
        child: SafeArea(
          child: StreamBuilder<List<QuerySnapshot>>(
            stream: CombineLatestStream.list([
              FirebaseFirestore.instance
                  .collection('events')
                  .where('isPublic', isEqualTo: true)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              FirebaseFirestore.instance
                  .collection('events')
                  .where('creatorId', isEqualTo: 'cwEVLXnIKvNkTOj2ld9WYTUXgFu2')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerLoading();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(context);
              }

              // Combine docs and deduplicate by id
              final Map<String, QueryDocumentSnapshot> uniqueDocs = {};
              for (var querySnapshot in snapshot.data!) {
                for (var doc in querySnapshot.docs) {
                  uniqueDocs[doc.id] = doc;
                }
              }

              final docs = uniqueDocs.values.toList();
              // Sort by timestamp descending
              docs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>?)?['timestamp'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              if (docs.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _buildEventCard(context, doc);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final String title = data['title']?.toString() ?? 'Untitled Event';
    final String place = data['place']?.toString() ?? '';
    final String imageUrl = data['imageUrl']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreenFromHome(eventId: doc.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB).withOpacity(0.65), // Warm Amber Glass
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.4), // Warm Gold Border
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _goldAccent.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Hero(
                  tag: imageUrl.isNotEmpty
                      ? 'event_image_${doc.id}'
                      : 'event_icon_${doc.id}',
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      () {
                        final placeholder = Container(
                          decoration: BoxDecoration(
                            gradient: HomeScreen.getEventPlaceholderData(
                              data['category'] ?? '',
                            )['gradient'] as LinearGradient?,
                          ),
                          child: Center(
                            child: Icon(
                              HomeScreen.getEventPlaceholderData(
                                data['category'] ?? '',
                              )['icon'] as IconData?,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        );

                        if (imageUrl.isEmpty) return placeholder;

                        if (imageUrl.startsWith('data:image/')) {
                          try {
                            final bytes = base64Decode(imageUrl.split(',').last);
                            return Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => placeholder,
                            );
                          } catch (_) {
                            return placeholder;
                          }
                        }

                        return Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => placeholder,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Shimmer.fromColors(
                              baseColor: Colors.grey.shade300,
                              highlightColor: Colors.white,
                              child: Container(
                                color: Colors.white,
                              ),
                            );
                          },
                        );
                      }(),
                      // Radiant Glow Overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Content Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: _primaryBlue,
                            height: 1.25,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _primaryBlue.withOpacity(0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (place.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: _goldAccent.withOpacity(0.8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            place,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: const Color(0xFF64748B), // Soft Slate
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB).withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
              ),
            ),
            child: Icon(
              Icons.event_note_rounded,
              size: 56,
              color: _goldAccent.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Events Yet',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Refining upcoming programs for you.',
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.white.withOpacity(0.5),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          return Container(
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
          );
        },
      ),
    );
  }
}

