import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminSchoolRegistrations extends StatelessWidget {
  const AdminSchoolRegistrations({super.key});

  Future<String> _fetchUserName(String userId) async {
    if (userId.isEmpty) return 'Unknown';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return 'Unknown';
      final data = doc.data();
      return data?['schoolName']?.toString() ??
          data?['schoolname']?.toString() ??
          data?['name']?.toString() ??
          'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'School Registrations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyState(
              icon: Icons.school_outlined,
              title: 'No registrations yet',
              message:
                  'Schools will appear here once they submit registrations.',
            );
          }

          final Map<String, _SchoolGroup> grouped = {};
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final schoolId = data['schoolUserId']?.toString() ?? 'unknown';
            final parishName = data['parishName']?.toString();
            final parishUserId = data['parishUserId']?.toString() ?? '';
            final schoolName =
                data['schoolName']?.toString() ?? 'Unknown School';
            final status = data['status']?.toString() ?? 'pending_parish';

            if (status == 'pending_parish') {
              // User request: "no need to display the pending parish entry"
              // So we skip counting it for the Admin View
              continue;
            }

            grouped.putIfAbsent(
              schoolId,
              () => _SchoolGroup(
                schoolId: schoolId,
                schoolName: schoolName,
                parishUserId: parishUserId,
                parishName: parishName,
              ),
            );
            final group = grouped[schoolId]!;
            if (group.parishName == null && parishName != null) {
              group.parishName = parishName;
            }
            group.total += 1;
            // if (status == 'pending_parish') group.pending += 1; // Skipped
            if (status == 'approved_parish') group.approved += 1;
            if (status == 'locked') group.locked += 1;
          }

          final groups = grouped.values.toList()
            ..sort((a, b) => a.schoolName.compareTo(b.schoolName));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final g = groups[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: FutureBuilder<String>(
                    future: _fetchUserName(g.schoolId),
                    builder: (context, snap) {
                      final name = snap.data ?? g.schoolName;
                      return Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                  subtitle: Text(
                    'Total: ${g.total} • Pending: ${g.pending} • Approved: ${g.approved} • Locked: ${g.locked}',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SchoolRegistrationDetail(group: g),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SchoolRegistrationDetail extends StatelessWidget {
  final _SchoolGroup group;
  const SchoolRegistrationDetail({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: AdminSchoolRegistrations()._fetchUserName(group.schoolId),
          builder: (context, snap) {
            final title = snap.data ?? group.schoolName;
            return Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .where('schoolUserId', isEqualTo: group.schoolId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return AdminSchoolRegistrations()._emptyState(
              icon: Icons.list_alt,
              title: 'No registrations found',
              message: 'This school has not submitted registrations yet.',
            );
          }

          // Group by program
          final Map<String, _ProgramGroup> programs = {};
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final programName =
                data['programName']?.toString() ?? 'Unknown Program';
            final status = data['status']?.toString() ?? 'pending_parish';
            final student = data['studentName'] ?? 'Unknown Student';
            final phone = data['studentPhone'] ?? 'N/A';
            final submitted =
                (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
            final parishName =
                data['parishName']?.toString() ?? group.parishName ?? '';

            programs.putIfAbsent(
              programName,
              () => _ProgramGroup(
                programName: programName,
                parishName: parishName,
              ),
            );
            programs[programName]!.entries.add(
              _RegistrationEntry(
                studentName: student.toString(),
                phone: phone.toString(),
                status: status,
                submitted: submitted,
                parishName: parishName,
              ),
            );
          }

          final programList = programs.values.toList()
            ..sort((a, b) => a.programName.compareTo(b.programName));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: programList.length,
            itemBuilder: (context, index) {
              final p = programList[index];
              final approved = p.entries
                  .where((e) => e.status == 'approved_parish')
                  .length;
              // START OF MODIFICATION: HIDE PENDING FROM COUNTS (Wait, we need to hide the List Card effectively if count is 0? Or just show 0?)
              // The user said: "only the accepted(ticked) entry should be available to the admin . no need to display the pending parish entry."
              // So I should effectively treat pending as invisible.
              final visibleEntries = p.entries
                  .where(
                    (e) =>
                        e.status == 'approved_parish' || e.status == 'locked',
                  )
                  .toList();

              if (visibleEntries.isEmpty)
                return const SizedBox.shrink(); // Don't show program if no approved entries

              final total = visibleEntries.length;
              final locked = visibleEntries
                  .where((e) => e.status == 'locked')
                  .length;
              // Pending is now 0 effectively for the Admin view
              final pending = 0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    p.programName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Total: $total • Pending: $pending • Approved: $approved • Locked: $locked',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProgramRegistrationsDetail(
                          program: p,
                          schoolName: group.schoolName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SchoolGroup {
  _SchoolGroup({
    required this.schoolId,
    required this.schoolName,
    required this.parishUserId,
    this.parishName,
  });

  final String schoolId;
  final String schoolName;
  final String parishUserId;
  String? parishName;
  int total = 0;
  int pending = 0;
  int approved = 0;
  int locked = 0;
}

class _ProgramGroup {
  _ProgramGroup({required this.programName, required this.parishName});
  final String programName;
  final String parishName;
  final List<_RegistrationEntry> entries = [];
}

class _RegistrationEntry {
  _RegistrationEntry({
    required this.studentName,
    required this.phone,
    required this.status,
    required this.submitted,
    required this.parishName,
  });

  final String studentName;
  final String phone;
  final String status;
  final DateTime submitted;
  final String parishName;
}

class ProgramRegistrationsDetail extends StatelessWidget {
  final _ProgramGroup program;
  final String schoolName;

  const ProgramRegistrationsDetail({
    super.key,
    required this.program,
    required this.schoolName,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_parish':
        return Colors.orange;
      case 'approved_parish':
        return Colors.blue;
      case 'locked':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        List<_RegistrationEntry>.from(program.entries)
            .where((e) => e.status != 'pending_parish') // Filter out pending
            .toList()
          ..sort((a, b) => b.submitted.compareTo(a.submitted));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${program.programName} • $schoolName',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.studentName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(entry.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: _statusColor(entry.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Phone: ${entry.phone}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (entry.parishName.isNotEmpty)
                    Text(
                      'Parish: ${entry.parishName}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  Text(
                    'Submitted: ${DateFormat('MMM dd, yyyy').format(entry.submitted)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
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
