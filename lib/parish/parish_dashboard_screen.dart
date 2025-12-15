import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/login_screen.dart';

class ParishDashboardScreen extends StatefulWidget {
  const ParishDashboardScreen({super.key});

  @override
  State<ParishDashboardScreen> createState() => _ParishDashboardScreenState();
}

class _ParishDashboardScreenState extends State<ParishDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<QuerySnapshot>? _pendingStream;
  Stream<QuerySnapshot>? _approvedStream;
  bool _isInit = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeStreams();
  }

  void _initializeStreams() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Fetch the Parish User's document to get the 'schoolId' they are assigned to.
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          // The Parish User document has 'schoolId' (created in admin_create_parish_user).
          final String? linkedSchoolId = data?['schoolId'];

          if (linkedSchoolId != null) {
            _pendingStream = FirebaseFirestore.instance
                .collection('program_registrations')
                .where(
                  'schoolUserId',
                  isEqualTo: linkedSchoolId,
                ) // Connect via School ID
                .where('status', isEqualTo: 'pending_parish')
                .snapshots();

            _approvedStream = FirebaseFirestore.instance
                .collection('program_registrations')
                .where(
                  'schoolUserId',
                  isEqualTo: linkedSchoolId,
                ) // Connect via School ID
                .where('status', isEqualTo: 'approved_parish')
                .snapshots();
          } else {
            debugPrint("Parish User has no linked schoolId.");
          }
        }
      } catch (e) {
        debugPrint("Error initializing streams: $e");
      } finally {
        if (mounted) {
          setState(() => _isInit = true);
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('program_registrations')
          .doc(docId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved_parish' ? 'Approved!' : 'Rejected',
            ),
            backgroundColor: newStatus == 'approved_parish'
                ? Colors.green
                : Colors.red,
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

  Future<void> _editRegistration(
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (_isSaving) return;
    final nameController = TextEditingController(
      text: data['studentName']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: data['studentPhone']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Registration',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Student Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Student Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedName = nameController.text.trim();
              final updatedPhone = phoneController.text.trim();
              if (updatedName.isEmpty || updatedPhone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name and phone are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() => _isSaving = true);
              try {
                await FirebaseFirestore.instance
                    .collection('program_registrations')
                    .doc(docId)
                    .update({
                      'studentName': updatedName,
                      'studentPhone': updatedPhone,
                    });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Registration updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      // If user was null in initState, try to re-init if user is now present (unlikely with AuthWrapper but safe)
      if (_auth.currentUser != null) {
        _initializeStreams();
      } else {
        return const Scaffold(body: Center(child: Text("Not Logged In")));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Parish Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegistrationList(_pendingStream, 'pending_parish'),
          _buildRegistrationList(_approvedStream, 'approved_parish'),
        ],
      ),
    );
  }

  Widget _buildRegistrationList(Stream<QuerySnapshot>? stream, String status) {
    if (stream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  status == 'pending_parish'
                      ? 'No pending approvals'
                      : 'No approved registrations',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
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
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isLocked = data['status'] == 'locked';

            return Card(
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
                        Text(
                          data['studentName'] ?? 'Unknown Student',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: isLocked
                                  ? null
                                  : () => _editRegistration(doc.id, data),
                              tooltip: 'Edit',
                            ),
                            if (status == 'pending_parish') ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    _updateStatus(doc.id, 'approved_parish'),
                                tooltip: 'Approve',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _updateStatus(doc.id, 'rejected'),
                                tooltip: 'Reject',
                              ),
                            ] else ...[
                              Icon(Icons.check, color: Colors.green.shade300),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Program: ${data['programName'] ?? 'Unknown Program'}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    Text(
                      'Phone: ${data['studentPhone'] ?? 'N/A'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
