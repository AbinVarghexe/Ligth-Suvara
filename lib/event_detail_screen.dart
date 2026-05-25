import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sundayschool_app/custom_app_bar.dart'; // Import the new appbar
import 'package:sundayschool_app/event_details_skelton.dart';
import 'package:sundayschool_app/homescreen.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';
import 'package:sundayschool_app/edit_event_screen.dart';
import 'package:sundayschool_app/report_generator.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:sundayschool_app/widgets/linkable_text.dart';

// DATA MODEL
class EventDetailsPageData {
  final DocumentSnapshot eventDoc;
  final bool canEdit;
  EventDetailsPageData({required this.eventDoc, required this.canEdit});
}

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<EventDetailsPageData> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchDetails();
  }

  void _refreshEventDetails() {
    setState(() {
      _detailsFuture = _fetchDetails();
    });
  }

  // --- DATA FETCHING & ACTIONS ---
  Future<EventDetailsPageData> _fetchDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    final eventDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .get();

    bool canEdit = false;
    if (user != null && eventDoc.exists) {
      final eventData = eventDoc.data() as Map<String, dynamic>;
      final isCreator = (eventData['creatorId'] ?? '') == user.uid;

      bool isAdmin = false;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['role'] == 'admin') {
          isAdmin = true;
        }
      }
      canEdit = isCreator || isAdmin;
    }

    return EventDetailsPageData(eventDoc: eventDoc, canEdit: canEdit);
  }

  void _editEvent(DocumentSnapshot eventDoc) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditEventScreen(eventDoc: eventDoc),
        fullscreenDialog: true,
      ),
    );
    if (result == true) {
      _refreshEventDetails();
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this event? This action cannot be undone and will permanently remove the event.',
          style: GoogleFonts.poppins(color: Colors.grey.shade700),
        ),
        // --- ✅ FIX: REMOVED Expanded WIDGETS ---
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Delete Permanently',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .delete();
        if (mounted) {
          _showStatusDialog(
            context: context,
            isSuccess: true,
            title: 'Deleted!',
            message: 'Event deleted successfully!',
            onDismiss: () => Navigator.of(context).pop(),
          );
        }
      } catch (e) {
        if (mounted) {
          _showStatusDialog(
            context: context,
            isSuccess: false,
            title: 'Failed',
            message: 'Failed to delete event: $e',
          );
        }
      }
    }
  }

  Future<void> _showStatusDialog({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final color = isSuccess ? const Color(0xFF22C55E) : Colors.red;
        final icon = isSuccess
            ? Icons.check_circle_rounded
            : Icons.error_rounded;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  "OK",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    ).then((_) => onDismiss?.call());
  }

  void _downloadReport(Map<String, dynamic> eventData) async {
    try {
      String creatorSchoolName = 'N/A';
      final creatorId = eventData['creatorId'];

      if (creatorId != null && creatorId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (userDoc.exists) {
          creatorSchoolName = userDoc.data()?['schoolname'] ?? 'N/A';
        }
      }

      final reportData = {...eventData, 'creatorSchoolName': creatorSchoolName};
      
      // 1. Show a loading dialog while pre-fetching assets
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1E40AF)),
                  const SizedBox(height: 20),
                  Text(
                    'Generating Report...',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // 2. Pre-fetch assets (Logo, Hero Image) outside the Print Dialog
      // This ensures the System Preview doesn't "hang" on the network request.
      final assets = await preFetchReportAssets(reportData);

      // 3. Close the loading dialog
      if (mounted) Navigator.of(context).pop();

      // 4. Open the System Print/Save Dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await generateEventReport(reportData, preFetchedAssets: assets, format: format),
        name: 'Event_Report_${widget.eventId}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('PDF Generation Error: $e');
    }
  }

  // --- UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<EventDetailsPageData>(
              future: _detailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const EventDetailSkeleton();
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.eventDoc.exists) {
                  return Center(
                    child: Text(
                      snapshot.hasError
                          ? 'Error: ${snapshot.error}'
                          : 'Event not found.',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                final pageData = snapshot.data!;
                final eventData =
                    pageData.eventDoc.data() as Map<String, dynamic>;

                return Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        slivers: [_buildSliverContent(eventData)],
                      ),
                    ),
                    _buildBottomActionArea(pageData, eventData),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildBottomActionArea(
    EventDetailsPageData pageData,
    Map<String, dynamic> eventData,
  ) {
    const themeColor = Color(0xFF1E40AF);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7).withOpacity(0.95), // Warm Cream
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.05), // Warm Shadow
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pageData.canEdit)
            _buildAdminActionRow(pageData.eventDoc, themeColor),
          ElevatedButton.icon(
            onPressed: () => _downloadReport(eventData),
            icon: const Icon(Icons.download_for_offline_outlined),
            label: const Text('View Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionRow(DocumentSnapshot eventDoc, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _editEvent(eventDoc),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _deleteEvent,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverContent(Map<String, dynamic> data) {
    final String description =
        data['description'] ?? 'No description provided.';
    final String place = data['place'] ?? 'Location not specified';
    final String title = data['title'] ?? 'Event Title';
    final Timestamp? dateTimestamp =
        data['timestamp'] as Timestamp?; // Corrected to use 'timestamp'
    final String category = (data['category'] ?? 'N/A').toUpperCase();
    final String dateTimeString = dateTimestamp != null
        ? DateFormat('MMMM d, yyyy, h:mm a').format(
            dateTimestamp.toDate(),
          ) // Corrected format
        : 'Date Unknown';

    return SliverPadding(
      padding: const EdgeInsets.all(20.0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          () {
            final String? rawImageUrl = data['imageUrl'];
            final bool hasValidImage = rawImageUrl != null &&
                rawImageUrl.isNotEmpty &&
                !rawImageUrl.contains('via.placeholder.com');
            final String finalImageUrl = hasValidImage ? rawImageUrl : '';
            final bool isBase64 = finalImageUrl.startsWith('data:image/');

            // Decode base64 once if needed
            Widget imageContent;
            if (finalImageUrl.isEmpty) {
              imageContent = Container(
                height: 220,
                width: double.infinity,
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
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              );
            } else if (isBase64) {
              try {
                final bytes = base64Decode(finalImageUrl.split(',').last);
                imageContent = Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  height: 220,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
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
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              } catch (_) {
                imageContent = const SizedBox.shrink();
              }
            } else {
              imageContent = Image.network(
                finalImageUrl,
                fit: BoxFit.cover,
                height: 220,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 220,
                    color: Colors.grey.shade100,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (c, o, s) => Container(
                  height: 220,
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
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }

            return Hero(
              tag: finalImageUrl.isNotEmpty
                  ? 'event_image_${widget.eventId}'
                  : 'event_icon_${widget.eventId}',
              child: GestureDetector(
                // Only allow full-screen tap for real network URLs (base64 is too large)
                onTap: (finalImageUrl.isNotEmpty && !isBase64)
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageViewer(
                              imageUrl: finalImageUrl,
                              heroTag: 'event_image_${widget.eventId}',
                            ),
                          ),
                        );
                      }
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageContent,
                ),
              ),
            );
          }(),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            "Date", // Corrected label
            dateTimeString,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_outlined, "Place", place),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.category_outlined, "Category", category),
          const Divider(height: 48, thickness: 1),
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
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1E40AF), size: 20),
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
