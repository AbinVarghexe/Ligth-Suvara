import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class SchoolMyRegistrationsScreen extends StatelessWidget {
  const SchoolMyRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("Please login")));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'My Registrations',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.blue.shade900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .where('schoolUserId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No registrations found",
                style: GoogleFonts.poppins(),
              ),
            );
          }

          // Group by Program
          final Map<String, int> programCounts = {};
          final Map<String, String> programIds = {};
          // Check lock status per program (if any entry is locked, program is locked)
          final Map<String, bool> programLocked = {};

          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final pName = data['programName'] as String? ?? 'Unknown';
            final pId = data['programId'] as String? ?? '';
            final status = data['status'] as String? ?? 'pending';

            programCounts[pName] = (programCounts[pName] ?? 0) + 1;
            programIds[pName] = pId;
            if (status == 'locked') {
              programLocked[pName] = true;
            }
          }

          final programs = programCounts.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final pName = programs[index];
              final count = programCounts[pName]!;
              final isLocked = programLocked[pName] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SchoolProgramDetailScreen(
                            programName: pName,
                            isLocked: isLocked,
                          ),
                        ),
                      );
                    },
                    title: Text(
                      pName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$count Students Registered',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isLocked
                                ? Colors.grey.shade100
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isLocked ? "Locked" : "Open",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isLocked
                                  ? Colors.grey.shade600
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SchoolProgramDetailScreen extends StatefulWidget {
  final String programName;
  final bool isLocked;

  const SchoolProgramDetailScreen({
    super.key,
    required this.programName,
    required this.isLocked,
  });

  @override
  State<SchoolProgramDetailScreen> createState() =>
      _SchoolProgramDetailScreenState();
}

class _SchoolProgramDetailScreenState extends State<SchoolProgramDetailScreen> {
  bool _isSaving = false;

  void _showEditBottomSheet(String docId, Map<String, dynamic> data) {
    if (widget.isLocked) return; // double check

    final nameController = TextEditingController(
      text: data['studentName']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: data['studentPhone']?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Student',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (nameController.text.isEmpty) return;

                        setState(() => _isSaving = true);
                        // Close sheet AFTER saving if successful?
                        // Current logic popped BEFORE saving.
                        // " Navigator.pop(ctx); ... setState(() => _isSaving = true);"
                        // If I pop first, this widget is disposed?
                        // The bottom sheet is modal. If I pop it, the context/widget might still be alive if it's the parent widget?
                        // Wait, _SchoolProgramDetailScreenState owns the methods.
                        // But the BottomSheet is separate.
                        // If I pop the bottom sheet, the user can't see the "Save Changes" button anymore to see the spinner!
                        // So I must NOT pop immediately if I want to show spinner ON the sheet.

                        try {
                          await FirebaseFirestore.instance
                              .collection('program_registrations')
                              .doc(docId)
                              .update({
                                'studentName': nameController.text.trim(),
                                'studentPhone': phoneController.text.trim(),
                              });
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Updated!")),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Save Changes",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.programName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.blue.shade900),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .where('schoolUserId', isEqualTo: user!.uid)
            .where('programName', isEqualTo: widget.programName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    data['studentName'] ?? 'Unknown',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    data['studentPhone'] ?? 'No Phone',
                    style: GoogleFonts.poppins(),
                  ),
                  trailing: widget.isLocked
                      ? const Icon(Icons.lock, color: Colors.grey)
                      : IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue.shade900),
                          onPressed: () => _showEditBottomSheet(doc.id, data),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
