import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Model to hold school data (no changes needed)
class School {
  final String id;
  final String name;
  final String email;

  School({required this.id, required this.name, required this.email});

  factory School.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return School(
      id: doc.id,
      name: data['schoolname'] ?? data['schoolName'] ?? 'Unnamed School',
      email: data['email'] ?? 'No Email',
    );
  }
}

class MultiSchoolSelectionScreen extends StatefulWidget {
  const MultiSchoolSelectionScreen({super.key});

  @override
  State<MultiSchoolSelectionScreen> createState() =>
      _MultiSchoolSelectionScreenState();
}

class _MultiSchoolSelectionScreenState
    extends State<MultiSchoolSelectionScreen> {
  // --- STATE FOR SEARCH ---
  final Set<String> _selectedSchoolIds = {};
  List<School> _allSchools = [];
  List<School> _filteredSchools = []; // For search results
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  // Define theme colors
  final Color themeColor = Colors.blue.shade900;
  final Color lightBackground = Colors.blue.shade50;
  final Color primaryColor = const Color(0xFF1E40AF);

  @override
  void initState() {
    super.initState();
    _fetchSchools();
    _searchController.addListener(_filterSchools);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'school')
          .get();

      final schools = snapshot.docs.map((doc) => School.fromDoc(doc)).toList();
      schools.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _allSchools = schools;
        _filteredSchools = schools; // Initially, show all schools
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching schools: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading schools: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterSchools() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSchools = _allSchools
          .where((school) => school.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _toggleSelection(String schoolId) {
    setState(() {
      if (_selectedSchoolIds.contains(schoolId)) {
        _selectedSchoolIds.remove(schoolId);
      } else {
        _selectedSchoolIds.add(schoolId);
      }
    });
  }

  void _confirmSelection() {
    if (_selectedSchoolIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one parish.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }
    // Return the list of selected IDs
    Navigator.of(context).pop(_selectedSchoolIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Use white background for modern feel
      appBar: AppBar(
        // Style AppBar
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          color: primaryColor,
        ),
        title: Text(
          'Select Parishes (${_selectedSchoolIds.length})',
          style:
          GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 19, color: primaryColor),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      // --- Floating Action Button ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmSelection,
        backgroundColor: themeColor,
        icon: const Icon(Icons.check, color: Colors.white),
        label: Text(
          'Confirm',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a parish...',
                hintStyle: GoogleFonts.poppins(),
                prefixIcon: Icon(Icons.search, color: primaryColor.withOpacity(0.7)),
                filled: true,
                fillColor: lightBackground.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ),
          // --- Main Content ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSchools.isEmpty
                ? Center(
                child: Text(
                  'No parishes found.',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ))
            // --- MODERNIZED LIST ---
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 80), // Padding for FAB
              itemCount: _filteredSchools.length,
              itemBuilder: (context, index) {
                final school = _filteredSchools[index];
                final isSelected =
                _selectedSchoolIds.contains(school.id);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? lightBackground : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? primaryColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                        blurRadius: isSelected ? 8 : 4,
                        offset: isSelected ? const Offset(0, 4) : const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: isSelected ? primaryColor : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    // Use CircleAvatar for leading icon
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? primaryColor : Colors.grey.shade100,
                      child: Icon(
                        Icons.school_outlined,
                        color: isSelected ? Colors.white : primaryColor.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      school.name,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? primaryColor : Colors.black87
                      ),
                    ),
                    subtitle: Text(
                      school.email,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600
                      ),
                    ),
                    // Modern selection indicator
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded,
                        color: Colors.green.shade600, size: 28)
                        : Icon(Icons.radio_button_off,
                        color: Colors.grey.shade400, size: 28),
                    onTap: () => _toggleSelection(school.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}