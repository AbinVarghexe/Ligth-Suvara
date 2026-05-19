import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'admin_observer_remarks_view.dart';

class AdminObserverManagementScreen extends StatefulWidget {
  const AdminObserverManagementScreen({super.key});

  @override
  State<AdminObserverManagementScreen> createState() =>
      _AdminObserverManagementScreenState();
}

class _AdminObserverManagementScreenState
    extends State<AdminObserverManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedAcademicYear = '2025-2026'; // Default
  List<String> _academicYears = ['2025-2026'];

  List<String> _generateAcademicYears() {
    final now = DateTime.now();
    int currentYear = now.year;
    // Base academic year is 2025-2026
    int startYear = 2025;
    // Ensure the list goes up to the "current year - next year"
    int endBound = currentYear;
    if (endBound < startYear) endBound = startYear;

    List<String> years = [];
    for (int y = startYear; y <= endBound; y++) {
      years.add('$y-${y + 1}');
    }
    return years;
  }


  @override
  void initState() {
    super.initState();
    _academicYears = _generateAcademicYears();
    _selectedAcademicYear = _academicYears.last; // Default to latest
    _tabController = TabController(length: 2, vsync: this);
    _tabController.animation!.addListener(() {
      if (mounted) {
        final int nextIndex = _tabController.animation!.value.round();
        if (nextIndex != _currentIndex) {
          setState(() {
            _currentIndex = nextIndex;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAssignObserverMenu(
    String targetSchoolId,
    String targetSchoolName,
    String academicYear,
  ) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ObserverAssignmentBottomSheet(
          targetSchoolId: targetSchoolId,
          targetSchoolName: targetSchoolName,
          academicYear: academicYear,
        );
      },
    );

    if (result != null) {
      final assignedOb = result['teacher'];
      final academicYear = result['academicYear'];
      try {
        final String accessCode = (Random().nextInt(900000) + 100000)
            .toString();

        await FirebaseFirestore.instance.collection('assignments').add({
          'teacherId': assignedOb['id'],
          'teacherName': assignedOb['name'],
          'teacherPhone': assignedOb['phone'],
          'sourceSchoolId': assignedOb['schoolId'],
          'sourceSchoolName': assignedOb['schoolName'],
          'targetSchoolId': targetSchoolId,
          'targetSchoolName': targetSchoolName,
          'accessCode': accessCode,
          'academicYear': academicYear,
          'assignedAt': FieldValue.serverTimestamp(),
          'type': 'Observer',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Observer assigned successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error assigning: $e')));
        }
      }
    }
  }

  Future<void> _removeAssignment(
    String assignmentId,
    String teacherName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Observer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to remove $teacherName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('assignments')
            .doc(assignmentId)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _setGlobalExpirationDate(BuildContext context) async {
    // 1. Fetch existing date to show as initial if it exists
    DateTime initialDate = DateTime.now();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('observer_dates')
          .collection('years')
          .doc(_selectedAcademicYear)
          .get();
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!['expirationDate'] != null) {
        initialDate = (doc.data()!['expirationDate'] as Timestamp).toDate();
      }
    } catch (e) {
      debugPrint('Error fetching existing expiration date: $e');
    }

    if (!context.mounted) return;

    // 2. Show Date Picker
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(DateTime.now().year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade900,
              onPrimary: Colors.white,
              onSurface: Colors.indigo.shade900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('settings')
            .doc('observer_dates')
            .collection('years')
            .doc(_selectedAcademicYear)
            .set({
              'expirationDate': Timestamp.fromDate(picked),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Global expiration date for $_selectedAcademicYear set to ${DateFormat('MMM dd, yyyy').format(picked)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to set expiration date: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Observer Management',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.edit_calendar_rounded,
                color: Colors.white,
              ),
              tooltip: 'Set Expiration Date',
              onPressed: () => _setGlobalExpirationDate(context),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAcademicYear,
                dropdownColor: Colors.indigo.shade900,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                icon: const Icon(Icons.history_rounded, color: Colors.white70),
                items: _academicYears
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedAcademicYear = v!),
              ),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade900, Colors.indigo.shade600],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Floating Segmented Control
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                backgroundColor: Colors.grey.shade100,
                thumbColor: Colors.white,
                groupValue: _currentIndex,
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Unassigned',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _currentIndex == 0
                            ? Colors.indigo.shade900
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Assigned',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _currentIndex == 1
                            ? Colors.indigo.shade900
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => _currentIndex = value);
                    _tabController.animateTo(value);
                  }
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search schools...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'school')
                  .snapshots(),
              builder: (context, schoolSnapshot) {
                if (schoolSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('assignments')
                      .where('type', isEqualTo: 'Observer')
                      .snapshots(),
                  builder: (context, assignmentSnapshot) {
                    if (assignmentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final schools = schoolSnapshot.data?.docs ?? [];
                    final assignments = (assignmentSnapshot.data?.docs ?? [])
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['academicYear'] == _selectedAcademicYear;
                        })
                        .toList();

                    final Map<String, dynamic> assignmentMap = {
                      for (var doc in assignments)
                        (doc.data() as Map<String, dynamic>)['targetSchoolId']
                            as String: {
                          'id': doc.id,
                          ...doc.data() as Map<String, dynamic>,
                        },
                    };

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSchoolList(schools, assignmentMap, false),
                        _buildSchoolList(schools, assignmentMap, true),
                      ],
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

  Widget _buildSchoolList(
    List<QueryDocumentSnapshot> schools,
    Map<String, dynamic> assignmentMap,
    bool showAssigned,
  ) {
    final filteredSchools = schools.where((doc) {
      final schoolId = doc.id;
      final hasAssignment = assignmentMap.containsKey(schoolId);
      final schoolData = doc.data() as Map<String, dynamic>;
      final name =
          (schoolData['schoolname'] ??
                  schoolData['name'] ??
                  schoolData['targetSchoolName'] ??
                  '')
              .toString()
              .toLowerCase();

      final matchesTab = showAssigned ? hasAssignment : !hasAssignment;
      final matchesSearch = name.contains(_searchQuery);

      return matchesTab && matchesSearch;
    }).toList();

    if (filteredSchools.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showAssigned ? Icons.assignment_turned_in : Icons.assignment_late,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              showAssigned
                  ? 'No assigned schools found'
                  : 'No unassigned schools found',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredSchools.length,
      itemBuilder: (context, index) {
        final schoolDoc = filteredSchools[index];
        final schoolId = schoolDoc.id;
        final schoolData = schoolDoc.data() as Map<String, dynamic>;
        final assignment = assignmentMap[schoolId];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: showAssigned && assignment != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminObserverRemarksViewScreen(
                          assignmentId: assignment['id'],
                        ),
                      ),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: showAssigned
                          ? Colors.indigo.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.school,
                      color: showAssigned
                          ? Colors.indigo.shade700
                          : Colors.orange.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schoolData['schoolname'] ??
                              schoolData['name'] ??
                              schoolData['targetSchoolName'] ??
                              'Unknown School',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        if (showAssigned && assignment != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Observer: ${assignment['teacherName']}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                          Text(
                            'From: ${assignment['sourceSchoolName']}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (assignment['examDate'] != null)
                            Text(
                              'Exam: ${(assignment['examDate'] as Timestamp).toDate().day}/${(assignment['examDate'] as Timestamp).toDate().month}/${(assignment['examDate'] as Timestamp).toDate().year} (${assignment['academicYear'] ?? ""})',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo.shade400,
                              ),
                            ),
                        ] else
                          Text(
                            'No observer assigned',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showAssigned && assignment != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            assignment['accessCode'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.visibility_outlined,
                                color: Colors.indigo.shade700,
                                size: 22,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminObserverRemarksViewScreen(
                                          assignmentId: assignment['id'],
                                        ),
                                  ),
                                );
                              },
                              tooltip: 'View Remarks',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              onPressed: () => _removeAssignment(
                                assignment['id'],
                                assignment['teacherName'],
                              ),
                              tooltip: 'Remove Assignment',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: () => _showAssignObserverMenu(
                        schoolId,
                        schoolData['schoolname'] ??
                            schoolData['name'] ??
                            schoolData['targetSchoolName'] ??
                            'School',
                        _selectedAcademicYear,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Assign'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ObserverAssignmentBottomSheet extends StatefulWidget {
  final String targetSchoolId;
  final String targetSchoolName;
  final String academicYear;
  const _ObserverAssignmentBottomSheet({
    required this.targetSchoolId,
    required this.targetSchoolName,
    required this.academicYear,
  });

  @override
  State<_ObserverAssignmentBottomSheet> createState() =>
      _ObserverAssignmentBottomSheetState();
}

class _ObserverAssignmentBottomSheetState
    extends State<_ObserverAssignmentBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Expanded(child: _buildTeacherSelection()),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTeacherSelection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                'Select Observer',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by teacher or school...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('assignments')
                .where('type', isEqualTo: 'Observer')
                .snapshots(),
            builder: (context, assignmentSnapshot) {
              if (assignmentSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final assignedTeacherIds =
                  assignmentSnapshot.data?.docs
                      .map((doc) => doc['teacherId'] as String)
                      .toSet() ??
                  {};

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('teachers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isSameSchool =
                        data['schoolId'] == widget.targetSchoolId;
                    final isAlreadyAssigned = assignedTeacherIds.contains(
                      doc.id,
                    );
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final schoolName = (data['schoolName'] ?? '')
                        .toString()
                        .toLowerCase();

                    return !isSameSchool &&
                        !isAlreadyAssigned &&
                        (name.contains(_searchQuery) ||
                            schoolName.contains(_searchQuery));
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No eligible teachers found',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.grey.shade100),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade50,
                            child: Icon(
                              Icons.person,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                          title: Text(
                            data['name'] ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            data['schoolName'] ?? 'Unknown School',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.pop(context, {
                              'teacher': {
                                'id': doc.id,
                                'name': data['name'],
                                'phone': data['phone'],
                                'schoolId': data['schoolId'],
                                'schoolName': data['schoolName'],
                              },
                              'academicYear': widget.academicYear,
                            });
                          },
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
    );
  }
}
