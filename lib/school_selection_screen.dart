// lib/school_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

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
              vertical: 14, horizontal: 16),
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
    // ... (This widget remains the same as provided previously)
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.blue.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBroadcast ? Colors.blue.shade50 : Colors.grey
                      .shade100,
                  borderRadius: BorderRadius.circular(8),
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
                    fontSize: 16,
                    fontWeight: isBroadcast ? FontWeight.w700 : FontWeight.w500,
                    color: isBroadcast ? const Color(0xFF1E3A8A) : const Color(
                        0xFF343A40),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFADB5BD)),
            ],
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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Select Recipient', style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4B5563)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(), // Display the search bar at the top

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: baseQuery.snapshots(), // Stream returns ALL documents
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return Center(
                      child: Text(
                          'No schools found.', style: GoogleFonts.poppins()));
                }

                // ➡️ CLIENT-SIDE FILTERING LOGIC (The core of the video's technique) ⬅️
                final allSchoolDocs = snapshot.data!.docs;

                final filteredSchoolDocs = allSchoolDocs.where((school) {
                  final data = school.data() as Map<String, dynamic>;
                  final schoolName = data['schoolname']
                      ?.toString()
                      .toLowerCase() ?? '';

                  // If search is empty, show all. Otherwise, check if name starts with query.
                  return _searchQuery.isEmpty ||
                      schoolName.startsWith(_searchQuery);
                }).toList();

                if (filteredSchoolDocs.isEmpty) {
                  String message = _searchQuery.isEmpty
                      ? 'No schools found.'
                      : 'No schools matching "$_searchQuery".';
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                            message, style: GoogleFonts.poppins(color: Colors
                            .grey.shade600)),
                      ));
                }

                // End client-side filtering logic

                return ListView.separated(
                  itemCount: filteredSchoolDocs.length + 1,
                  // Use filtered list count
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFE5E7EB)),
                  itemBuilder: (context, index) {
                    // --- 1. Add "Broadcast to All" as the first item ---
                    if (index == 0) {
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
                    final school = filteredSchoolDocs[index -
                        1]; // Use filtered list
                    final data = school.data() as Map<String, dynamic>;

                    // NOTE: Display name will be lowercase unless you apply TitleCase formatting
                    final displayName = data['schoolname']?.toString() ??
                        'Unnamed School';

                    return _buildSelectionTile(
                      icon: Icons.school_outlined,
                      title: displayName,
                      onTap: () {
                        Navigator.of(context).pop({
                          'id': school.id,
                          'name': displayName,
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}