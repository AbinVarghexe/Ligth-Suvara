// lib/school_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class SchoolSelectionScreen extends StatefulWidget {
  final bool enableBroadcast; // Controls visibility of "Broadcast to All"
  final bool
  excludeAssignedSchools; // Filters out schools with existing parish users

  const SchoolSelectionScreen({
    super.key,
    this.enableBroadcast = true, // Default to true for backward compatibility
    this.excludeAssignedSchools = false,
  });

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen> {
  // --- STATE AND CONTROLLERS ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // State variable holds the lowercase query string

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // ➡️ Standardizes input to lowercase for case-insensitive comparison ⬅️
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  // --- WIDGETS ---

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search schools...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
        ),
      ),
    );
  }

  // --- Reusable Tile Widget for both Broadcast and Schools ---
  Widget _buildSelectionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF495057),
    bool isBroadcast = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isBroadcast ? Colors.blue.shade100 : Colors.grey.shade100,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.blue.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isBroadcast
                        ? Colors.blue.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isBroadcast ? Colors.blue.shade700 : iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: isBroadcast
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isBroadcast
                          ? Colors.blue.shade900
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- FIREBASE QUERY LOGIC (Fetch All Schools) ---
    // ➡️ FIX: Simplified query to fetch all documents where role='school' ⬅️
    Query baseQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'school')
        .orderBy('schoolname'); // Still sorting for initial display

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
          'Select Recipient',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            _buildSearchBar(), // Display the search bar at the top

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.excludeAssignedSchools
                    ? FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'parish')
                          .snapshots()
                    : const Stream.empty(),
                builder: (context, parishSnapshot) {
                  // If we are excluding assigned schools and the parish data is loading, show loading
                  if (widget.excludeAssignedSchools &&
                      parishSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final assignedSchoolIds = <String>{};
                  if (widget.excludeAssignedSchools && parishSnapshot.hasData) {
                    for (var doc in parishSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['schoolId'] != null) {
                        assignedSchoolIds.add(data['schoolId'] as String);
                      }
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: baseQuery
                        .snapshots(), // Stream returns ALL documents
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData) {
                        return Center(
                          child: Text(
                            'No schools found.',
                            style: GoogleFonts.poppins(),
                          ),
                        );
                      }

                      // ➡️ CLIENT-SIDE FILTERING LOGIC ⬅️
                      final allSchoolDocs = snapshot.data!.docs;

                      final filteredSchoolDocs = allSchoolDocs.where((school) {
                        // Filter out if already assigned to a parish user (if flag is true)
                        if (widget.excludeAssignedSchools &&
                            assignedSchoolIds.contains(school.id)) {
                          return false;
                        }

                        final data = school.data() as Map<String, dynamic>;
                        final schoolName =
                            data['schoolname']?.toString().toLowerCase() ?? '';

                        // Search filter
                        return _searchQuery.isEmpty ||
                            schoolName.startsWith(_searchQuery);
                      }).toList();

                      if (filteredSchoolDocs.isEmpty) {
                        String message;
                        if (widget.excludeAssignedSchools &&
                            _searchQuery.isEmpty) {
                          message = 'All schools already have Parish Users.';
                        } else {
                          message = _searchQuery.isEmpty
                              ? 'No schools found.'
                              : 'No schools matching "$_searchQuery".';
                        }

                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              message,
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      // Logic to adjust item count and index based on enableBroadcast
                      final int itemCount = widget.enableBroadcast
                          ? filteredSchoolDocs.length + 1
                          : filteredSchoolDocs.length;

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          // --- 1. Add "Broadcast to All" as the first item if enabled ---
                          if (widget.enableBroadcast && index == 0) {
                            return _buildSelectionTile(
                              icon: Icons.campaign_rounded,
                              title: 'Broadcast to All Schools',
                              isBroadcast: true,
                              onTap: () {
                                Navigator.of(context).pop({
                                  'id': 'all',
                                  'name': 'Broadcast to All Schools',
                                });
                              },
                            );
                          }

                          // --- 2. School List Item ---
                          final int listIndex = widget.enableBroadcast
                              ? index - 1
                              : index;

                          final school = filteredSchoolDocs[listIndex];
                          final data = school.data() as Map<String, dynamic>;
                          final displayName =
                              data['schoolname']?.toString() ??
                              'Unnamed School';

                          return _buildSelectionTile(
                            icon: Icons.school_outlined,
                            title: displayName,
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pop({'id': school.id, 'name': displayName});
                            },
                          );
                        },
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
