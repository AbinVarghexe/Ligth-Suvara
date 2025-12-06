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
  Set<String> _assignedSchoolIds = {}; // IDs of schools already assigned
  bool _isLoadingSchools = true;

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
      final assigned = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final list = data['assignments'] as List<dynamic>? ?? [];
        for (var item in list) {
          if (item is Map && item['schoolUserId'] != null) {
            assigned.add(item['schoolUserId']);
          }
        }
      }
      if (mounted) {
        setState(() {
          _assignedSchoolIds = assigned;
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

    if (_assignedSchoolIds.contains(_selectedSchoolId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This school is already assigned to another animator'),
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
          const SnackBar(content: Text('School assigned successfully')),
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

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Change Assigned School',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            // Include currently assigned school so we don't hide it, but show unassigned ones primarily
            final validSchools = _allSchools.where((doc) {
              return !_assignedSchoolIds.contains(doc.id) ||
                  doc.id == oldAssignment['schoolUserId'];
            }).toList();

            return DropdownButtonFormField<String>(
              isExpanded: true,
              value: newSchoolId,
              hint: const Text("Select New School"),
              decoration: _buildInputDecoration(Icons.school),
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
            ),
            child: Text('Update', style: GoogleFonts.poppins()),
          ),
        ],
      ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assignment updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  InputDecoration _buildInputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.blue.shade700),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade900, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter available schools for the dropdown
    final availableSchoolsForDropdown = _allSchools.where((doc) {
      return !_assignedSchoolIds.contains(doc.id);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Animator Selection
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.05),
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
                  return const Center(child: CircularProgressIndicator());
                }

                final animators = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  value: _selectedAnimatorId,
                  hint: Text('Select Animator', style: GoogleFonts.poppins()),
                  decoration: _buildInputDecoration(Icons.person),
                  items: animators.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        data['name'] ?? data['email'] ?? 'Unknown',
                        style: GoogleFonts.inter(),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAnimatorId = val),
                );
              },
            ),
          ),

          // 2. Assignment Form
          if (_selectedAnimatorId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                elevation: 4,
                shadowColor: Colors.blue.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_link_rounded,
                            color: Colors.blue.shade900,
                          ),
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 16),
                      _isLoadingSchools
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<String>(
                              value: _selectedSchoolId,
                              isExpanded: true,
                              hint: Text(
                                "Select School (Parish - Name)",
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                              decoration: _buildInputDecoration(
                                Icons.school_outlined,
                              ),
                              items: availableSchoolsForDropdown.map((doc) {
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
                              onChanged: (val) =>
                                  setState(() => _selectedSchoolId = val),
                            ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _assignButton,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: Colors.blue.shade200,
                        ),
                        child: Text(
                          "Assign School",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('animator_assignments').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
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
                        final userName =
                            userSnap.data?.get('name') ?? 'Loading...';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: Text(
                                  userName.isNotEmpty ? userName[0] : '?',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                "$userName",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "${assignments.length} assignments",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              iconColor: Colors.blue.shade900,
                              children: assignments.map((a) {
                                final map = a as Map<String, dynamic>;
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      map['sundaySchool'] ?? 'Unknown School',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Parish: ${map['parish'] ?? 'Unknown'}",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          "Forane: ${map['forane'] ?? 'Unknown'}",
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _editAssignment(
                                            animatorDoc.id,
                                            map,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _removeAssignment(
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
    );
  }
}
