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
          SnackBar(
            content: const Text('Registration Locked Successfully'),
            backgroundColor: Colors.grey.shade800,
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
          'Review Registrations',
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
            _buildFilterSection(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No registrations found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs.toList();
                  // Client-side search
                  final filtered = docs.where((d) {
                    final data = d.data();
                    final isCountOnly = data['isCountOnly'] == true;
                    final student = isCountOnly
                        ? '${data['studentCount']} Students'
                        : (data['studentName'] ?? '').toString().toLowerCase();
                    final program = (data['programName'] ?? '')
                        .toString()
                        .toLowerCase();
                    if (_search.isEmpty) return true;
                    return student.contains(_search) ||
                        program.contains(_search);
                  }).toList();

                  filtered.sort((a, b) {
                    final aDate = (a.data())['submittedAt'] as Timestamp?;
                    final bDate = (b.data())['submittedAt'] as Timestamp?;
                    if (aDate == null && bDate == null) return 0;
                    if (aDate == null) return 1;
                    if (bDate == null) return -1;
                    return bDate.toDate().compareTo(aDate.toDate());
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data();
                      return _buildAnimatedRegistrationCard(doc, data, index);
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

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: GoogleFonts.inter(),
            decoration: InputDecoration(
              hintText: 'Search student or program...',
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.blue.shade700,
                size: 22,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (val) {
              setState(() => _search = val.trim().toLowerCase());
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.blue.shade700,
                ),
                items: _statusOptions
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s == 'all'
                              ? 'Show All Status'
                              : s.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _selectedStatus = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedRegistrationCard(
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    int index,
  ) {
    final date = (data['submittedAt'] as Timestamp?)?.toDate();
    final status = data['status']?.toString() ?? 'unknown';
    final schoolName = data['schoolName']?.toString() ?? 'Unknown';
    // final parishId = data['parishUserId']?.toString() ?? 'N/A'; // Removed parish user ID to clean up UI
    final programName = data['programName']?.toString() ?? 'Unknown';
    final bool isCountOnly = data['isCountOnly'] == true;
    final studentName = data['studentName'] ?? 'Unknown Student';
    final int studentCount = data['studentCount'] ?? 1;

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
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCountOnly
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCountOnly ? Icons.groups_rounded : Icons.person_rounded,
                      color: isCountOnly
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCountOnly ? '+$studentCount Students' : studentName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          programName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'approved_parish')
                    ElevatedButton.icon(
                      onPressed: () => _lockRegistration(doc.id),
                      icon: const Icon(Icons.lock_rounded, size: 14),
                      label: Text(
                        'LOCK',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    )
                  else
                    _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schoolName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.phone_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCountOnly
                        ? 'No details'
                        : (data['studentPhone'] ?? 'N/A'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (date != null)
                    Text(
                      DateFormat('MMM dd, yyyy').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label = status.replaceAll('_', ' ').toUpperCase();

    switch (status) {
      case 'locked':
        bg = Colors.purple.shade50;
        text = Colors.purple.shade700;
        break;
      case 'rejected':
        bg = Colors.red.shade50;
        text = Colors.red.shade700;
        break;
      case 'pending_parish':
        bg = Colors.orange.shade50;
        text = Colors.orange.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bg == Colors.white ? text : bg),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: text,
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'program_registrations',
    );
    if (_selectedStatus != 'all') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }
    return query.snapshots();
  }
}
