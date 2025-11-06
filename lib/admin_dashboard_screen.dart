// lib/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sundayschool_app/admin_notification_screen.dart';
import 'package:sundayschool_app/event_detail_screen.dart';
import 'package:sundayschool_app/edit_event_screen.dart';
import 'package:sundayschool_app/login_screen.dart';

// Re-define SortOption for modularity (originally in homescreen.dart)
enum SortOption { newestFirst, alphabetical }

// Re-define EventListSkeleton for modularity (originally in homescreen.dart)
class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget buildShimmerBlock(
        {required double height,
          double width = double.infinity,
          double radius = 15.0}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                buildShimmerBlock(height: 60, width: 60, radius: 10),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildShimmerBlock(height: 16, width: 200),
                      const SizedBox(height: 8),
                      buildShimmerBlock(height: 14, width: 150),
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
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // --- STATE VARIABLES ---
  int _selectedCategoryIndex = 0; // 0: ALL, 1: CML, 2: SUVARA
  final List<String> _categories = ['ALL', 'CML', 'SUVARA'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  SortOption _currentSortOption = SortOption.newestFirst;

  // Statistics counters
  int _totalEvents = 0;
  int _publicEvents = 0;
  int _draftEvents = 0;

  // Loading state for statistics fetch
  bool _isStatsLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchAndSetStatistics();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  // --- ACTIONS ---

  Future<void> _fetchAndSetStatistics() async {
    if (_isStatsLoading) return;

    setState(() {
      _isStatsLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection('events').get();

      final allEvents = snapshot.docs;
      final total = allEvents.length;
      final public = allEvents.where((doc) => (doc.data())['isPublic'] == true).length;
      final draft = total - public;

      if (mounted) {
        setState(() {
          _totalEvents = total;
          _publicEvents = public;
          _draftEvents = draft;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load statistics: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStatsLoading = false;
        });
      }
    }
  }


  Future<void> _sendToPublic(BuildContext context, String eventId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({'isPublic': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event marked as Public!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Operation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sort Events By', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortOption>(
                title: Text('Newest First', style: GoogleFonts.poppins()),
                value: SortOption.newestFirst,
                groupValue: _currentSortOption,
                onChanged: (value) {
                  if (value != null) {
                    setState(() { _currentSortOption = value; });
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<SortOption>(
                title: Text('Alphabetical (A-Z)', style: GoogleFonts.poppins()),
                value: SortOption.alphabetical,
                groupValue: _currentSortOption,
                onChanged: (value) {
                  if (value != null) {
                    setState(() { _currentSortOption = value; });
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to delete all events associated with a specific, possibly deleted, UID
  Future<void> _deleteEventsByUserId(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    String? deletedUserId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete User Events', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Enter Deleted User ID (UID)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (deletedUserId == null || deletedUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cleanup canceled or no ID provided.')),
        );
      }
      return;
    }

    setState(() { _isStatsLoading = true; });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('creatorId', isEqualTo: deletedUserId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No events found for user ID: $deletedUserId'),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
        return;
      }

      final writeBatch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        writeBatch.delete(doc.reference);
      }
      await writeBatch.commit();

      if (mounted) {
        await _fetchAndSetStatistics();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${querySnapshot.docs.length} events deleted for user ID: $deletedUserId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isStatsLoading = false; });
      }
    }
  }


  // --- UI BUILDER METHODS ---

  // FIX 1: Wrap Row in IntrinsicHeight for equal height distribution
  Widget _buildStatisticsCards(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: _isStatsLoading
          ? const Center(child: LinearProgressIndicator()) // Show loading indicator
          : IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Makes Expanded children fill the height
          children: [
            _buildStatCard('Total Events', _totalEvents, Icons.list, themeColor),
            const SizedBox(width: 10),
            _buildStatCard('Public', _publicEvents, Icons.public, Colors.green),
            const SizedBox(width: 10),
            _buildStatCard('Drafts', _draftEvents, Icons.visibility_off, Colors.red),
          ],
        ),
      ),
    );
  }

  // FIX 2: Ensure the inner Container takes full height defined by IntrinsicHeight
  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        height: double.infinity, // Force the Container to take the max height of the Row
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  count.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCategoryFilter() {
    final Color themeColor = Colors.blue.shade900;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(_categories.length, (index) {
          final isSelected = _selectedCategoryIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedCategoryIndex = index;
                  // Clear search when changing category for simpler UX
                  _searchController.clear();
                });
              },
              child: Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: isSelected ? themeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _categories[index],
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : themeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by event title...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.blue.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildAllEventsList() {
    final selectedCategory = _categories[_selectedCategoryIndex];

    // Fetch ALL events (admin view)
    Query baseQuery = FirebaseFirestore.instance.collection('events')
        .orderBy('timestamp', descending: true);

    if (selectedCategory != 'ALL') {
      baseQuery = baseQuery.where('category', isEqualTo: selectedCategory.toLowerCase());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EventListSkeleton();
        }

        // Handle Errors and empty data sets before processing
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('requires an index')) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Database Index Required for this combination of query filters.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
              ),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final eventDocs = snapshot.data!.docs;

        // --- Client-side filtering for SEARCH ---
        List<DocumentSnapshot> filteredDocs = eventDocs;

        if (_searchQuery.isNotEmpty) {
          filteredDocs = eventDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery);
          }).toList();
        }

        // --- Client-side SORTING ---
        if (_currentSortOption == SortOption.alphabetical) {
          filteredDocs.sort((a, b) {
            String aTitle = (a.data() as Map<String, dynamic>)['title']?.toString().toLowerCase() ?? '';
            String bTitle = (b.data() as Map<String, dynamic>)['title']?.toString().toLowerCase() ?? '';
            return aTitle.compareTo(bTitle);
          });
        }

        if (filteredDocs.isEmpty) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No events matching "$_searchQuery".'
                          : (selectedCategory == 'ALL' ? "No events found." : "No events found for $selectedCategory."),
                      style: GoogleFonts.poppins(color: Colors.grey.shade600)
                  )
              )
          );
        }

        // --- List View ---
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var eventDoc = filteredDocs[index];
            var data = eventDoc.data() as Map<String, dynamic>;
            final bool isPublic = data['isPublic'] ?? false;
            final bool isDraft = !isPublic;

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 2,
              color: isDraft ? Colors.red.shade50 : Colors.blue.shade50,
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EventDetailScreen(eventId: eventDoc.id),
                    ),
                  );
                },
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: isDraft ? Colors.red.shade100 : Colors.blue.shade100,
                    child: data['imageUrl'] != null
                        ? Image.network(
                      data['imageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) =>
                      const Icon(Icons.broken_image, color: Colors.white),
                    )
                        : const Icon(Icons.image, color: Colors.white),
                  ),
                ),
                title: Text(
                  data['title'] ?? 'No Title',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category: ${(data['category'] ?? 'N/A').toUpperCase()}',
                      style: GoogleFonts.poppins(color: Colors.blue[700], fontSize: 13),
                    ),
                    Text(
                      isPublic ? 'Status: Public' : 'Status: Draft',
                      style: GoogleFonts.poppins(
                        color: isPublic ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Send to Public Button
                    if (!isPublic)
                      ElevatedButton(
                        onPressed: () => _sendToPublic(context, eventDoc.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Publish',
                          style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 28)
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = Colors.blue.shade900;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: themeColor),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          },
        ),
        title: Text('Admin Dashboard', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: themeColor)),
        backgroundColor: Colors.white,
        foregroundColor: themeColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.cleaning_services_outlined, color: Colors.red.shade700),
            onPressed: _isStatsLoading ? null : () => _deleteEventsByUserId(context),
            tooltip: 'Delete Events of Deleted User',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _isStatsLoading ? Colors.grey : themeColor),
            onPressed: _isStatsLoading ? null : _fetchAndSetStatistics,
            tooltip: 'Refresh Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminNotificationScreen())),
            tooltip: 'Send Notification',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showSortDialog,
            tooltip: 'Sort Events',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CORE CHANGE: Modernized Header
            Text(
              'Event Management Overview',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: themeColor),
            ),

            // CORE CHANGE: Statistics Cards
            _buildStatisticsCards(themeColor),

            const SizedBox(height: 16),
            Text(
              'Filters',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            _buildModernCategoryFilter(),
            const SizedBox(height: 16),
            _buildSearchBox(),
            const SizedBox(height: 24),
            Text(
              'Event List',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            _buildAllEventsList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
