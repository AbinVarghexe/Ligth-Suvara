import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sundayschool_app/admin_notification_screen.dart';
import 'package:sundayschool_app/event_detail_screen.dart';

import 'package:sundayschool_app/login_screen.dart';
import 'package:sundayschool_app/admin/admin_question_manager.dart';
import 'package:sundayschool_app/admin/admin_assignment_manager.dart';
import 'package:sundayschool_app/admin/admin_marks_viewer.dart';
import 'package:sundayschool_app/admin/admin_manage_animators.dart';
import 'package:sundayschool_app/admin/admin_create_animator.dart';
import 'package:sundayschool_app/admin/admin_program_manager.dart';

enum SortOption { newestFirst, alphabetical }

class EventListSkeleton extends StatelessWidget {
  const EventListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    Widget buildShimmerBlock({
      required double height,
      double width = double.infinity,
      double radius = 15.0,
    }) {
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
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  buildShimmerBlock(height: 80, width: 80, radius: 16),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildShimmerBlock(height: 20, width: 200),
                        const SizedBox(height: 8),
                        buildShimmerBlock(height: 16, width: 150),
                        const SizedBox(height: 8),
                        buildShimmerBlock(height: 14, width: 100),
                      ],
                    ),
                  ),
                ],
              ),
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

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['ALL', 'CML', 'SUVARA'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  SortOption _currentSortOption = SortOption.newestFirst;

  int _totalEvents = 0;
  int _publicEvents = 0;
  int _draftEvents = 0;

  bool _isStatsLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchAndSetStatistics();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _fetchAndSetStatistics() async {
    if (_isStatsLoading) return;

    setState(() {
      _isStatsLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .get();

      final allEvents = snapshot.docs;
      final total = allEvents.length;
      final public = allEvents
          .where((doc) => (doc.data())['isPublic'] == true)
          .length;
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
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to load statistics: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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

  Future<void> _toggleEventVisibility(
    BuildContext context,
    String eventId,
    bool currentStatus,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).update(
        {'isPublic': !currentStatus},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  !currentStatus ? Icons.check_circle : Icons.lock,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  !currentStatus
                      ? 'Event published successfully!'
                      : 'Event moved to drafts',
                ),
              ],
            ),
            backgroundColor: !currentStatus
                ? Colors.green.shade600
                : Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _fetchAndSetStatistics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Operation failed: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sort,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Sort Events',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSortOption(
                  title: 'Newest First',
                  icon: Icons.access_time,
                  value: SortOption.newestFirst,
                  context: context,
                ),
                const SizedBox(height: 12),
                _buildSortOption(
                  title: 'Alphabetical (A-Z)',
                  icon: Icons.sort_by_alpha,
                  value: SortOption.alphabetical,
                  context: context,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required SortOption value,
    required BuildContext context,
  }) {
    final isSelected = _currentSortOption == value;
    return InkWell(
      onTap: () {
        setState(() {
          _currentSortOption = value;
        });
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue.shade900 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.blue.shade900),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.blue.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEventsByUserId(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    String? deletedUserId = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever,
                  color: Colors.red.shade700,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete User Events',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the User ID to delete all associated events',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Enter Deleted User ID (UID)",
                  prefixIcon: Icon(
                    Icons.person_off,
                    color: Colors.red.shade700,
                  ),
                  filled: true,
                  fillColor: Colors.red.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete All',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (deletedUserId == null || deletedUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Cleanup canceled or no ID provided.'),
              ],
            ),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isStatsLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('creatorId', isEqualTo: deletedUserId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('No events found for user ID: $deletedUserId'),
                  ),
                ],
              ),
              backgroundColor: Colors.blueGrey,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${querySnapshot.docs.length} events deleted for user ID: $deletedUserId',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to delete events: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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

  Widget _buildStatisticsCards(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: _isStatsLoading
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade100,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(),
              ),
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildGradientStatCard(
                      'Total Events',
                      _totalEvents,
                      Icons.event_note_rounded,
                      [Colors.blue.shade700, Colors.blue.shade900],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGradientStatCard(
                      'Public',
                      _publicEvents,
                      Icons.public_rounded,
                      [Colors.green.shade600, Colors.green.shade800],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGradientStatCard(
                      'Drafts',
                      _draftEvents,
                      Icons.drafts_rounded,
                      [Colors.orange.shade600, Colors.orange.shade800],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGradientStatCard(
    String title,
    int count,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    (count * value).toInt().toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernCategoryFilter() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_categories.length, (index) {
          final isSelected = _selectedCategoryIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _selectedCategoryIndex = index;
                  _searchController.clear();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [Colors.blue.shade700, Colors.blue.shade900],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.blue.shade300,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _categories[index],
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          hintText: 'Search events...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.blue.shade700,
            size: 26,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildAllEventsList() {
    final selectedCategory = _categories[_selectedCategoryIndex];

    Query baseQuery = FirebaseFirestore.instance
        .collection('events')
        .orderBy('timestamp', descending: true);

    if (selectedCategory != 'ALL') {
      baseQuery = baseQuery.where(
        'category',
        isEqualTo: selectedCategory.toLowerCase(),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EventListSkeleton();
        }

        if (snapshot.hasError) {
          if (snapshot.error.toString().contains('requires an index')) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Database Index Required",
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "This query combination requires an index",
                      style: GoogleFonts.poppins(color: Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        final eventDocs = snapshot.data!.docs;

        List<DocumentSnapshot> filteredDocs = eventDocs;

        if (_searchQuery.isNotEmpty) {
          filteredDocs = eventDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title']?.toString().toLowerCase() ?? '';
            return title.contains(_searchQuery);
          }).toList();
        }

        if (_currentSortOption == SortOption.alphabetical) {
          filteredDocs.sort((a, b) {
            String aTitle =
                (a.data() as Map<String, dynamic>)['title']
                    ?.toString()
                    .toLowerCase() ??
                '';
            String bTitle =
                (b.data() as Map<String, dynamic>)['title']
                    ?.toString()
                    .toLowerCase() ??
                '';
            return aTitle.compareTo(bTitle);
          });
        }

        if (filteredDocs.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.event_busy,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No events matching "$_searchQuery"'
                        : (selectedCategory == 'ALL'
                              ? "No events found"
                              : "No events found for $selectedCategory"),
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var eventDoc = filteredDocs[index];
            var data = eventDoc.data() as Map<String, dynamic>;
            final bool isPublic = data['isPublic'] ?? false;

            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 50)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isPublic
                              ? [Colors.white, Colors.green.shade50]
                              : [Colors.white, Colors.orange.shade50],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isPublic
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EventDetailScreen(eventId: eventDoc.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Event Image with Status Badge
                                Stack(
                                  children: [
                                    Hero(
                                      tag: 'event_${eventDoc.id}',
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          gradient: LinearGradient(
                                            colors: isPublic
                                                ? [
                                                    Colors.green.shade200,
                                                    Colors.green.shade400,
                                                  ]
                                                : [
                                                    Colors.orange.shade200,
                                                    Colors.orange.shade400,
                                                  ],
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: data['imageUrl'] != null
                                              ? Image.network(
                                                  data['imageUrl'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (ctx, err, st) => Icon(
                                                        Icons
                                                            .broken_image_rounded,
                                                        color: Colors.white,
                                                        size: 40,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.image_rounded,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isPublic
                                              ? Colors.green.shade600
                                              : Colors.orange.shade600,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (isPublic
                                                          ? Colors.green
                                                          : Colors.orange)
                                                      .withOpacity(0.5),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          isPublic ? Icons.public : Icons.lock,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Event Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title'] ?? 'No Title',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blue.shade900,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          (data['category'] ?? 'N/A')
                                              .toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.blue.shade900,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isPublic
                                                  ? Colors.green.shade600
                                                  : Colors.orange.shade600,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isPublic ? 'Published' : 'Draft',
                                            style: GoogleFonts.poppins(
                                              color: isPublic
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Action Button - Responsive Design
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isPublic
                                          ? [
                                              Colors.orange.shade500,
                                              Colors.orange.shade700,
                                            ]
                                          : [
                                              Colors.green.shade500,
                                              Colors.green.shade700,
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isPublic
                                                    ? Colors.orange
                                                    : Colors.green)
                                                .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        _toggleEventVisibility(
                                          context,
                                          eventDoc.id,
                                          isPublic,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPublic
                                                  ? Icons.unpublished
                                                  : Icons.publish,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isPublic
                                                  ? 'Unpublish'
                                                  : 'Publish',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
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
                    ),
                  ),
                );
              },
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
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade700, Colors.blue.shade900],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade300.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: () async {
                // Show logout confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Logout',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      'Are you sure you want to logout?',
                      style: GoogleFonts.poppins(),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Logout', style: GoogleFonts.poppins()),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                }
              },
            ),
            actions: [
              _buildAppBarAction(
                icon: Icons.cleaning_services_outlined,
                color: Colors.red.shade300,
                onPressed: _isStatsLoading
                    ? null
                    : () => _deleteEventsByUserId(context),
                tooltip: 'Delete User Events',
              ),
              _buildAppBarAction(
                icon: Icons.refresh_rounded,
                color: _isStatsLoading ? Colors.grey.shade400 : Colors.white,
                onPressed: _isStatsLoading ? null : _fetchAndSetStatistics,
                tooltip: 'Refresh Statistics',
              ),
              _buildAppBarAction(
                icon: Icons.notifications_active_rounded,
                color: Colors.white,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminNotificationScreen(),
                  ),
                ),
                tooltip: 'Send Notification',
              ),
              _buildAppBarAction(
                icon: Icons.sort_rounded,
                color: Colors.white,
                onPressed: _showSortDialog,
                tooltip: 'Sort Events',
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Management',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: themeColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage and monitor all events',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Statistics Cards
              _buildStatisticsCards(themeColor),

              const SizedBox(height: 24),

              // Animator Management Section
              Text(
                'Animator Management',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  // Row 1
                  Row(
                    children: [
                      Expanded(
                        child: _buildAdminActionCard(
                          context,
                          'Questions',
                          Icons.quiz,
                          Colors.purple,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminQuestionManager(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAdminActionCard(
                          context,
                          'Assignments',
                          Icons.assignment_ind,
                          Colors.orange,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminAssignmentManager(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAdminActionCard(
                          context,
                          'View Marks',
                          Icons.grade,
                          Colors.teal,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminMarksViewer(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2
                  Row(
                    children: [
                      Expanded(
                        child: _buildAdminActionCard(
                          context,
                          'Manage Animators',
                          Icons.manage_accounts_outlined,
                          Colors.indigo,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminManageAnimators(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAdminActionCard(
                          context,
                          'Create Animator',
                          Icons.person_add_outlined,
                          Colors.blue,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminCreateAnimator(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(), // Keeps layout balanced
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Program Management Section
              Text(
                'Program Management',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAdminActionCard(
                      context,
                      'Manage Programs', // New Feature
                      Icons.event_available_outlined,
                      Colors.purpleAccent,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminProgramManager(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Spacer(), // Keeps layout balanced
                  const SizedBox(width: 12),
                  const Spacer(), // Keeps layout balanced
                ],
              ),
              const SizedBox(height: 24),
              _buildModernCategoryFilter(),
              const SizedBox(height: 16),
              _buildSearchBox(),

              const SizedBox(height: 32),

              // Event List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Events',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _currentSortOption == SortOption.newestFirst
                          ? 'Newest First'
                          : 'A-Z',
                      style: GoogleFonts.poppins(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Event List
              _buildAllEventsList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildAdminActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
