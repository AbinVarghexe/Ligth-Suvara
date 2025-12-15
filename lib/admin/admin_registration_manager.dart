import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminRegistrationManager extends StatefulWidget {
  const AdminRegistrationManager({super.key});

  @override
  State<AdminRegistrationManager> createState() =>
      _AdminRegistrationManagerState();
}

class _AdminRegistrationManagerState extends State<AdminRegistrationManager> {
  final List<String> _statusOptions = [
    'all',
    'pending_parish',
    'approved_parish',
    'locked',
    'rejected',
  ];
  String _selectedStatus = 'approved_parish';
  String _search = '';
  final _searchController = TextEditingController();

  void _lockRegistration(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('program_registrations')
          .doc(docId)
          .update({'status': 'locked'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Locked Successfully'),
            backgroundColor: Colors.grey,
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
      appBar: AppBar(
        title: Text(
          'Review Registrations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search student or program',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                    onChanged: (val) {
                      setState(() => _search = val.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: _statusOptions
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s == 'all'
                                ? 'All'
                                : s.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _selectedStatus = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 60,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No registrations waiting for lock',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs.toList();
          // Client-side search
          final filtered = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final student =
                (data['studentName'] ?? '').toString().toLowerCase();
            final program =
                (data['programName'] ?? '').toString().toLowerCase();
            if (_search.isEmpty) return true;
            return student.contains(_search) || program.contains(_search);
          }).toList();

          filtered.sort((a, b) {
            final aDate =
                (a.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
            final bDate =
                (b.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?;
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return bDate.toDate().compareTo(aDate.toDate());
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['submittedAt'] as Timestamp?)?.toDate();
              final status = data['status']?.toString() ?? 'unknown';
              final schoolName = data['schoolName']?.toString() ?? 'Unknown';
              final parishId = data['parishUserId']?.toString() ?? 'N/A';
              final programName = data['programName']?.toString() ?? 'Unknown';
              final studentName = data['studentName'] ?? 'Unknown Student';

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
                              studentName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (status == 'approved_parish')
                            ElevatedButton.icon(
                              onPressed: () => _lockRegistration(doc.id),
                              icon: const Icon(Icons.lock, size: 16),
                              label: const Text('LOCK'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade800,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Program: $programName',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      Text(
                        'School: $schoolName',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      Text(
                        'Parish User: $parishId',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      Text(
                        'Phone: ${data['studentPhone'] ?? 'N/A'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (date != null)
                        Text(
                          'Submitted: ${DateFormat('MMM dd, yyyy').format(date)}',
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
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('program_registrations');
    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    return query.snapshots();
  }
}
