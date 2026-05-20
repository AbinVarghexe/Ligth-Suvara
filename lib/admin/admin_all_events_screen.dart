import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/event_detail_screen.dart';
import 'package:sundayschool_app/homescreen.dart';

// Reusing SortOption from Dashboard or redefining if private
enum SortOption { newestFirst, alphabetical }

class AdminAllEventsScreen extends StatefulWidget {
  const AdminAllEventsScreen({super.key});

  @override
  State<AdminAllEventsScreen> createState() => _AdminAllEventsScreenState();
}

class _AdminAllEventsScreenState extends State<AdminAllEventsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  SortOption _currentSortOption = SortOption.newestFirst;

  String? _selectedSchoolId;
  String? _selectedSchoolName;
  String _selectedCategory = 'All'; // New state for category filter

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSchoolFilterDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: _SearchableSchoolDialog(
              onSelect: (id, name) {
                setState(() {
                  _selectedSchoolId = id;
                  _selectedSchoolName = name;
                });
              },
            ),
          ),
        );
      },
    );
  }

  void _showSortDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sort Events',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSortOption(
                      icon: Icons.access_time_rounded,
                      label: 'Newest First',
                      isSelected: _currentSortOption == SortOption.newestFirst,
                      onTap: () {
                        setState(
                          () => _currentSortOption = SortOption.newestFirst,
                        );
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSortOption(
                      icon: Icons.sort_by_alpha_rounded,
                      label: 'Alphabetical (A-Z)',
                      isSelected: _currentSortOption == SortOption.alphabetical,
                      onTap: () {
                        setState(
                          () => _currentSortOption = SortOption.alphabetical,
                        );
                        Navigator.pop(context);
                      },
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

  Widget _buildSortOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade200 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(
                Icons.check_circle_rounded,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- NEW: Segmented Filter Widget ---
  Widget _buildSegmentedFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildFilterSegment('All'),
          _buildFilterSegment('CML'),
          _buildFilterSegment('Suvara'),
        ],
      ),
    );
  }

  Widget _buildFilterSegment(String category) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade800 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.shade200.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            category.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              // Using Outfit for a modern look as requested
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
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
            content: Text(
              !currentStatus ? 'Event published!' : 'Event moved to drafts',
            ),
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'All Events',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
            onPressed: _showSortDialog,
          ),
        ],
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50.withOpacity(0.5), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + kToolbarHeight,
            ),

            // Filter Section
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: _searchController.clear,
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // School Filter Button
                  InkWell(
                    onTap: _showSchoolFilterDialog,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedSchoolId != null
                            ? Colors.blue.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedSchoolId != null
                              ? Colors.blue.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _selectedSchoolId != null
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.filter_list_rounded,
                              size: 16,
                              color: _selectedSchoolId != null
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedSchoolId != null
                                      ? 'Filtering by School'
                                      : 'Filter by School',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _selectedSchoolId != null
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade500,
                                    fontWeight: _selectedSchoolId != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  _selectedSchoolName ?? 'All Schools',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (_selectedSchoolId != null)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSchoolId = null;
                                  _selectedSchoolName = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade400,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildSegmentedFilter(),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final allDocs = snapshot.data!.docs;
                  List<DocumentSnapshot> filteredDocs = allDocs;

                  // 1. School Filter
                  if (_selectedSchoolId != null) {
                    filteredDocs = filteredDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['creatorId'] == _selectedSchoolId;
                    }).toList();
                  }

                  // 2. Category Filter (NEW)
                  if (_selectedCategory != 'All') {
                    filteredDocs = filteredDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final category = (data['category'] ?? '')
                          .toString()
                          .toLowerCase();
                      return category == _selectedCategory.toLowerCase();
                    }).toList();
                  }

                  // 2. Text Search
                  if (_searchQuery.isNotEmpty) {
                    filteredDocs = filteredDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title =
                          data['title']?.toString().toLowerCase() ?? '';
                      return title.contains(_searchQuery);
                    }).toList();
                  }

                  // 3. Sort (Alphabetical only, Database did NEWEST)
                  if (_currentSortOption == SortOption.alphabetical) {
                    filteredDocs.sort((a, b) {
                      final tA =
                          (a.data() as Map<String, dynamic>)['title']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      final tB =
                          (b.data() as Map<String, dynamic>)['title']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      return tA.compareTo(tB);
                    });
                  }

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_busy_rounded,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No events found',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isPublic = (data['isPublic'] ?? false) || (data['creatorId'] == 'cwEVLXnIKvNkTOj2ld9WYTUXgFu2');

                      return TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 1.0),
                          1.0,
                          curve: Curves.easeOut,
                        ),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade900.withOpacity(0.06),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.grey.shade100,
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EventDetailScreen(eventId: doc.id),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty)
                                        ? 'event_image_${doc.id}'
                                        : 'event_icon_${doc.id}',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: () {
                                          final imgUrl = (data['imageUrl'] ?? '') as String;
                                          final placeholderData = HomeScreen.getEventPlaceholderData(data['category'] ?? '');
                                          final placeholder = Container(
                                            width: 80, height: 80,
                                            decoration: BoxDecoration(
                                              gradient: placeholderData['gradient'] as LinearGradient?,
                                            ),
                                            child: Center(child: Icon(placeholderData['icon'] as IconData?, color: Colors.white, size: 32)),
                                          );
                                          if (imgUrl.isEmpty) return placeholder;
                                          // Handle base64 data URLs (stored by older uploads)
                                          if (imgUrl.startsWith('data:image/')) {
                                            try {
                                              final bytes = base64Decode(imgUrl.split(',').last);
                                              return Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => placeholder);
                                            } catch (_) { return placeholder; }
                                          }
                                          return Image.network(
                                            imgUrl,
                                            width: 80, height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => placeholder,
                                            loadingBuilder: (_, child, progress) {
                                              if (progress == null) return child;
                                              return Container(
                                                width: 80, height: 80,
                                                color: Colors.grey.shade200,
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              );
                                            },
                                          );
                                        }(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
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
                                            color: Colors.grey.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            (data['category'] ?? 'General')
                                                .toString()
                                                .toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isPublic
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: isPublic
                                              ? Colors.green.shade400
                                              : Colors.orange.shade400,
                                        ),
                                        onPressed: () => _toggleEventVisibility(
                                          context,
                                          doc.id,
                                          isPublic,
                                        ),
                                        tooltip: isPublic
                                            ? 'Public Event'
                                            : 'Draft Event',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchableSchoolDialog extends StatefulWidget {
  final Function(String? id, String? name) onSelect;
  const _SearchableSchoolDialog({required this.onSelect});

  @override
  State<_SearchableSchoolDialog> createState() =>
      _SearchableSchoolDialogState();
}

class _SearchableSchoolDialogState extends State<_SearchableSchoolDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _search = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    // A customized, beautiful dialog
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Select School',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      hintText: 'Search school...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.blue.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // List
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'school')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final docs = snapshot.data!.docs;

                  final filtered = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? data['schoolName'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No schools found',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade50,
                            child: Icon(
                              Icons.all_inclusive_rounded,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'All Schools (Reset)',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          onTap: () {
                            widget.onSelect(null, null);
                            Navigator.pop(context);
                          },
                        );
                      }

                      final doc = filtered[index - 1];
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          data['name']?.toString() ??
                          data['schoolname']?.toString() ??
                          'Unknown';

                      // Filter out "Unknown" or basically empty names if better UI desired,
                      // but for now keeping them as requested logic usually implies full data.

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade50,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.grey.shade300,
                        ),
                        onTap: () {
                          widget.onSelect(doc.id, name);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  foregroundColor: Colors.grey.shade600,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
