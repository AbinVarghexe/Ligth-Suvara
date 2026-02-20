import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class AdminAssignmentManager extends StatefulWidget {
  const AdminAssignmentManager({super.key});

  @override
  State<AdminAssignmentManager> createState() => _AdminAssignmentManagerState();
}

class _AdminAssignmentManagerState extends State<AdminAssignmentManager> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Selection State
  String? _selectedAnimatorId;
  String? _selectedSchoolId; // ID of the school user to assign

  // Data State
  List<DocumentSnapshot> _allSchools = [];
  // School ID -> Set of Years it is assigned for
  Map<String, Set<String>> _assignedSchoolsByYear = {};
  bool _isLoadingSchools = true;
  String _selectedYear = DateTime.now().year.toString();

  @override
  void initState() {
    super.initState();
    _fetchSchools();
    _listenToAssignments();
  }

  // --- 1. Fetch Data ---

  Future<void> _fetchSchools() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'school')
          .orderBy('schoolname')
          .get();

      if (mounted) {
        setState(() {
          _allSchools = snapshot.docs;
          _isLoadingSchools = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching schools: $e");
      if (mounted) setState(() => _isLoadingSchools = false);
    }
  }

  void _listenToAssignments() {
    _firestore.collection('animator_assignments').snapshots().listen((
      snapshot,
    ) {
      final assignedMap = <String, Set<String>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final list = data['assignments'] as List<dynamic>? ?? [];
        for (var item in list) {
          if (item is Map && item['schoolUserId'] != null) {
            final schoolId = item['schoolUserId'] as String;
            final year =
                item['year'] as String? ?? DateTime.now().year.toString();

            if (!assignedMap.containsKey(schoolId)) {
              assignedMap[schoolId] = {};
            }
            assignedMap[schoolId]!.add(year);
          }
        }
      }
      if (mounted) {
        setState(() {
          _assignedSchoolsByYear = assignedMap;
        });
      }
    });
  }

  // --- 2. Actions ---

  Future<void> _assignButton() async {
    if (_selectedAnimatorId == null || _selectedSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an animator and a school')),
      );
      return;
    }

    final schoolsAssignedThisYear = _assignedSchoolsByYear[_selectedSchoolId];
    if (schoolsAssignedThisYear != null &&
        schoolsAssignedThisYear.contains(_selectedYear)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This school is already assigned for $_selectedYear'),
        ),
      );
      return;
    }

    // Find selected school details safely
    final schoolDoc = _allSchools.firstWhere(
      (doc) => doc.id == _selectedSchoolId,
    );
    final schoolData = schoolDoc.data() as Map<String, dynamic>;

    final assignment = {
      'unitId': const Uuid().v4().substring(0, 8),
      'schoolUserId': _selectedSchoolId,
      'schoolname': schoolData['schoolname'] ?? 'Unknown School',
      'parish': schoolData['parish'] ?? 'Unknown Parish',
      'forane': schoolData['forane'] ?? 'Unknown Forane',
    };

    try {
      final docRef = _firestore
          .collection('animator_assignments')
          .doc(_selectedAnimatorId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        List<dynamic> assignments = [];
        if (snapshot.exists) {
          assignments = snapshot.data()?['assignments'] ?? [];
        }

        if (assignments.length >= 2) {
          throw Exception('Animator already has 2 schools assigned.');
        }

        assignments.add({
          'unitId': assignment['unitId'],
          'schoolUserId': assignment['schoolUserId'],
          'sundaySchool': assignment['schoolname'],
          'parish': assignment['parish'], // Actually Parish
          'forane': assignment['forane'], // Actually Forane
          'year': _selectedYear,
        });

        transaction.set(docRef, {
          'assignments': assignments,
        }, SetOptions(merge: true));
      });

      setState(() {
        _selectedSchoolId = null; // Reset selection
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('School assigned successfully'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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

  Future<void> _removeAssignment(
    String animatorId,
    Map<String, dynamic> assignment,
  ) async {
    try {
      await _firestore
          .collection('animator_assignments')
          .doc(animatorId)
          .update({
            'assignments': FieldValue.arrayRemove([assignment]),
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editAssignment(
    String animatorId,
    Map<String, dynamic> oldAssignment,
  ) async {
    String? newSchoolId;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Change Assigned School',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: StatefulBuilder(
                builder: (context, setState) {
                  // Include currently assigned school so we don't hide it, but show unassigned ones primarily
                  final validSchools = _allSchools.where((doc) {
                    final assignmentYear =
                        oldAssignment['year']?.toString() ??
                        DateTime.now().year.toString();
                    final assignedYears = _assignedSchoolsByYear[doc.id];
                    final isAssignedForYear =
                        assignedYears != null &&
                        assignedYears.contains(assignmentYear);
                    return !isAssignedForYear ||
                        doc.id == oldAssignment['schoolUserId'];
                  }).toList();

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: newSchoolId,
                    hint: const Text("Select New School"),
                    decoration: _buildInputDecoration(
                      Icons.school,
                      label: 'New School',
                    ),
                    items: validSchools.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(
                          "${data['schoolname']} (${data['forane'] ?? 'No Forane'})",
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => newSchoolId = val),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newSchoolId != null) {
                      Navigator.pop(context);
                      await _replaceAssignment(
                        animatorId,
                        oldAssignment,
                        newSchoolId!,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Update', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _replaceAssignment(
    String animatorId,
    Map<String, dynamic> oldAssignment,
    String newSchoolId,
  ) async {
    try {
      final schoolDoc = _allSchools.firstWhere((doc) => doc.id == newSchoolId);
      final schoolData = schoolDoc.data() as Map<String, dynamic>;

      final newAssignment = {
        'unitId': const Uuid().v4().substring(0, 8),
        'schoolUserId': newSchoolId,
        'sundaySchool': schoolData['schoolname'],
        'parish': schoolData['parish'] ?? 'Unknown Parish',
        'forane': schoolData['forane'] ?? 'Unknown Forane',
        'year': oldAssignment['year'] ?? DateTime.now().year.toString(),
      };

      final docRef = _firestore
          .collection('animator_assignments')
          .doc(animatorId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        List<dynamic> assignments = snapshot.data()?['assignments'] ?? [];
        // Remove old based on unique unitId
        assignments.removeWhere((a) => a['unitId'] == oldAssignment['unitId']);
        // Add new
        assignments.add(newAssignment);

        transaction.update(docRef, {'assignments': assignments});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assignment updated'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  InputDecoration _buildInputDecoration(IconData icon, {String? label}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue.shade700),
      labelStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade800, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter available schools for the dropdown
    final availableSchoolsForDropdown = _allSchools.where((doc) {
      // Check if this school is assigned for the currently selected year
      final assignedYears = _assignedSchoolsByYear[doc.id];
      if (assignedYears == null) return true; // Not assigned at all
      return !assignedYears.contains(
        _selectedYear,
      ); // Available if not assigned for THIS year
    }).toList();

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
          'Assign Schools',
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
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
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

            // 0. Academic Year Selection
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Academic Year:',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedYear,
                        isExpanded: true,
                        items:
                            [
                              DateTime.now().year.toString(),
                              (DateTime.now().year + 1).toString(),
                            ].map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYear = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 1. Animator Selection
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
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users')
                    .where('role', isEqualTo: 'animator')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final animators = snapshot.data!.docs;

                  return DropdownButtonFormField<String>(
                    value: _selectedAnimatorId,
                    hint: Text(
                      'Select Animator',
                      style: GoogleFonts.inter(color: Colors.grey.shade600),
                    ),
                    decoration: _buildInputDecoration(
                      Icons.person_outline_rounded,
                    ),
                    items: animators.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(
                          data['name'] ?? data['email'] ?? 'Unknown',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedAnimatorId = val),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.blue.shade700,
                    ),
                  );
                },
              ),
            ),

            // 2. Assignment Form (Collapsible)
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: _selectedAnimatorId != null
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade900.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.add_link_rounded,
                                    color: Colors.blue.shade800,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Assign New School",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _isLoadingSchools
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedSchoolId,
                                    isExpanded: true,
                                    hint: Text(
                                      "Select School",
                                      style: GoogleFonts.inter(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    decoration: _buildInputDecoration(
                                      Icons.school_outlined,
                                    ),
                                    items: availableSchoolsForDropdown.map((
                                      doc,
                                    ) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      return DropdownMenuItem(
                                        value: doc.id,
                                        child: Text(
                                          "${data['schoolname']}",
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedSchoolId = val),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _assignButton,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade900,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "Assign School",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // 3. List Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Assignments Overview",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // 4. List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('animator_assignments')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final animatorDoc = docs[index];
                      final assignments =
                          animatorDoc['assignments'] as List<dynamic>? ?? [];
                      if (assignments.isEmpty) return const SizedBox.shrink();

                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore
                            .collection('users')
                            .doc(animatorDoc.id)
                            .get(),
                        builder: (context, userSnap) {
                          String userName = 'Loading...';
                          if (userSnap.hasData) {
                            if (userSnap.data!.exists) {
                              try {
                                userName = userSnap.data!.get('name');
                              } catch (e) {
                                userName = 'Unknown';
                              }
                            } else {
                              userName = 'User Deleted';
                            }
                          }

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
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: Colors.grey.shade100),
                              ),
                              child: Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  backgroundColor: Colors.transparent,
                                  collapsedBackgroundColor: Colors.transparent,
                                  tilePadding: const EdgeInsets.all(16),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text(
                                        userName.isNotEmpty
                                            ? userName[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.poppins(
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    userName,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "${assignments.length} assignments",
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  iconColor: Colors.blue.shade300,
                                  collapsedIconColor: Colors.grey.shade400,
                                  children: assignments.map((a) {
                                    final map = a as Map<String, dynamic>;
                                    return Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                        title: Text(
                                          map['schoolname'] ??
                                              'Unknown School',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.church_rounded,
                                                  size: 14,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "${map['parish'] ?? 'Unknown'}",
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_rounded,
                                                color: Colors.blue.shade400,
                                                size: 20,
                                              ),
                                              onPressed: () => _editAssignment(
                                                animatorDoc.id,
                                                map,
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.red.shade400,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _removeAssignment(
                                                    animatorDoc.id,
                                                    map,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
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
