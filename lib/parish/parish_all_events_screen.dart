import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../homescreen.dart';
import 'package:intl/intl.dart';
import 'package:sundayschool_app/event_detail_screen_from_home.dart';

class ParishAllEventsScreen extends StatefulWidget {
  final String? linkedSchoolId;
  const ParishAllEventsScreen({super.key, this.linkedSchoolId});

  @override
  State<ParishAllEventsScreen> createState() => _ParishAllEventsScreenState();
}

class _ParishAllEventsScreenState extends State<ParishAllEventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatEventTime(Timestamp? timestamp) {
    if (timestamp == null) return 'No time set';
    final DateTime dt = timestamp.toDate();
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue.shade900, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Events',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by title or location...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.blue.shade900),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          // Events List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('creatorId', isEqualTo: widget.linkedSchoolId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allDocs = snapshot.data?.docs ?? [];
                
                // Filter locally by search query
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final place = (data['place'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) || place.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final eventId = doc.id;

                    return _buildEventCard(eventId, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(String eventId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade900.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreenFromHome(
                eventId: eventId,
              ),
            ),
          );
        },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'event_$eventId',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.blue.shade50,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Builder(
                        builder: (context) {
                          final String? imageUrl = data['imageUrl'];
                          final bool hasValidImage = imageUrl != null &&
                              imageUrl.isNotEmpty &&
                              !imageUrl.contains('via.placeholder.com');
                          final placeholder = HomeScreen.getEventPlaceholderData(
                            data['category']?.toString() ?? '',
                          );

                          if (hasValidImage) {
                            return Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => Container(
                                decoration: BoxDecoration(
                                  gradient: placeholder['gradient']
                                      as LinearGradient?,
                                ),
                                child: Center(
                                  child: Icon(
                                    placeholder['icon'] as IconData?,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              decoration: BoxDecoration(
                                gradient:
                                    placeholder['gradient'] as LinearGradient?,
                              ),
                              child: Center(
                                child: Icon(
                                  placeholder['icon'] as IconData?,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            );
                          }
                        },
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
                        data['title'] ?? 'Untitled Event',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['place'] ?? 'Unknown location',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatEventTime(data['timestamp'] as Timestamp?),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.blue.shade700,
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No events found' : 'No matching events',
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
