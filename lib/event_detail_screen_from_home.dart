import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';
import 'package:sundayschool_app/widgets/linkable_text.dart';
import 'package:cached_network_image/cached_network_image.dart';

// This is the dedicated screen to show the full details of a single event.
class EventDetailScreenFromHome extends StatefulWidget {
  final String eventId;

  const EventDetailScreenFromHome({super.key, required this.eventId});

  @override
  State<EventDetailScreenFromHome> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreenFromHome> {
  // A Future to hold the asynchronous data-fetching operation.
  late Future<DocumentSnapshot> _detailsFuture;

  @override
  void initState() {
    super.initState();
    // Start fetching the data as soon as the screen is initialized.
    _detailsFuture = _fetchEventDetails();
  }

  // Fetches the specific event document from Firestore using the passed eventId.
  Future<DocumentSnapshot> _fetchEventDetails() {
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // FutureBuilder is perfect for handling loading/error/data states.
      body: FutureBuilder<DocumentSnapshot>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          // 1. While the data is loading, show the modern shimmer effect.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EventDetailSkeleton();
          }

          // 2. If there's an error or the event doesn't exist, show a message.
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return Center(
              child: Text(
                snapshot.hasError ? 'An error occurred.' : 'Event not found.',
                style: GoogleFonts.poppins(),
              ),
            );
          }

          // 3. If data is successfully loaded, display it.
          final eventData = snapshot.data!.data() as Map<String, dynamic>;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(
                  'Event Details',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade900,
                surfaceTintColor: Colors.white,
                elevation: 1,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // The main content of the screen is built here.
              _buildSliverContent(eventData),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS FOR DISPLAYING CONTENT ---

  // Builds the main scrollable content area.
  Widget _buildSliverContent(Map<String, dynamic> data) {
    // Safely extract data from the map, providing default values.
    final String description =
        data['description'] ?? 'No description provided.';
    final String place = data['place'] ?? 'Location not specified';
    final String title = data['title'] ?? 'Event Title';
    final Timestamp? dateTimestamp = data['timestamp'] as Timestamp?;
    final String dateTimeString = dateTimestamp != null
        ? DateFormat('MMMM d, yyyy  •  h:mm a').format(dateTimestamp.toDate())
        : 'Date/Time Unknown';

    return SliverPadding(
      padding: const EdgeInsets.all(20.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // --- Event Image ---
          () {
            final String? rawImageUrl = data['imageUrl'];
            final bool hasValidImage = rawImageUrl != null &&
                rawImageUrl.isNotEmpty &&
                !rawImageUrl.contains('via.placeholder.com');
            final String finalImageUrl = hasValidImage ? rawImageUrl : '';

            final placeholderData = HomeScreen.getEventPlaceholderData(data['category'] ?? '');
            final placeholder = Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: placeholderData['gradient'] as LinearGradient?,
              ),
              child: Center(
                child: Icon(
                  placeholderData['icon'] as IconData?,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            );

            Widget imageWidget;
            bool isBase64 = false;
            if (finalImageUrl.isNotEmpty) {
              if (finalImageUrl.startsWith('data:image/')) {
                isBase64 = true;
                try {
                  final bytes = base64Decode(finalImageUrl.split(',').last);
                  imageWidget = Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    height: 220,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => placeholder,
                  );
                } catch (_) {
                  imageWidget = placeholder;
                }
              } else {
                imageWidget = CachedNetworkImage(
                  imageUrl: finalImageUrl,
                  fit: BoxFit.cover,
                  height: 220,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    height: 220,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (c, o, s) => placeholder,
                );
              }
            } else {
              imageWidget = placeholder;
            }

            return GestureDetector(
              onTap: finalImageUrl.isNotEmpty
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageViewer(
                            imageUrl: finalImageUrl,
                            heroTag: 'event_image_${widget.eventId}',
                          ),
                        ),
                      );
                    }
                  : null,
              child: Hero(
                tag: finalImageUrl.isNotEmpty
                    ? 'event_image_${widget.eventId}'
                    : 'event_icon_${widget.eventId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageWidget,
                ),
              ),
            );
          }(),
          const SizedBox(height: 24),

          // --- Event Title ---
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 16),

          // --- Info Rows (Date & Place) ---
          _buildInfoRow(
            Icons.calendar_today_outlined,
            "Date & Time",
            dateTimeString,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_outlined, "Place", place),
          const Divider(height: 48, thickness: 1),

          // --- Description Section ---
          Text(
            "About this Event",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LinkableText(
            description,
            linkColor: const Color(0xFF1E40AF),
            style: GoogleFonts.poppins(
              fontSize: 16,
              height: 1.7,
              color: Colors.blue.shade900.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40), // Final padding at the bottom
        ]),
      ),
    );
  }

  // A helper widget to create a consistent row style for info items.
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue.shade800, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ⭐️ A modern skeleton loader for the Event Detail Screen ⭐️
class EventDetailSkeleton extends StatelessWidget {
  const EventDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Helper to build a single shimmer block
    Widget buildShimmerBlock({
      required double height,
      double width = double.infinity,
      double radius = 8,
    }) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.black, // Base color for shimmer
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        physics:
            const NeverScrollableScrollPhysics(), // Disable scrolling during load
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Skeleton
            buildShimmerBlock(height: 220, radius: 16),
            const SizedBox(height: 24),

            // Title Skeleton
            buildShimmerBlock(height: 30, width: 250),
            const SizedBox(height: 16),

            // Info Row Skeleton
            buildShimmerBlock(height: 40, width: double.infinity),
            const SizedBox(height: 12),
            buildShimmerBlock(height: 40, width: double.infinity),
            const Divider(height: 48, thickness: 1),

            // Description Header Skeleton
            buildShimmerBlock(height: 24, width: 200),
            const SizedBox(height: 16),

            // Description Lines Skeleton
            buildShimmerBlock(height: 16),
            const SizedBox(height: 8),
            buildShimmerBlock(height: 16),
            const SizedBox(height: 8),
            buildShimmerBlock(height: 16, width: 280),
          ],
        ),
      ),
    );
  }
}
