import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/animator/student_registration_form.dart';

class SchoolMyRegistrationsScreen extends StatelessWidget {
  const SchoolMyRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'My Registrations',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade700],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
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

            final isCountOnly = data['isCountOnly'] == true;
            final studentCount = isCountOnly
                ? (data['studentCount'] as int? ?? 1)
                : 1;

            programCounts[pName] = (programCounts[pName] ?? 0) + studentCount;
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
                            programId: programIds[pName] ?? '',
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
                        '$count Member${count == 1 ? '' : 's'} Registered',
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
  final String programId;
  final bool isLocked;

  const SchoolProgramDetailScreen({
    super.key,
    required this.programName,
    required this.programId,
    required this.isLocked,
  });

  @override
  State<SchoolProgramDetailScreen> createState() =>
      _SchoolProgramDetailScreenState();
}

class _SchoolProgramDetailScreenState extends State<SchoolProgramDetailScreen> {
  bool _isSaving = false;

  void _deleteRegistration(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Delete',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this registration? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('program_registrations')
            .doc(docId)
            .delete();
        if (mounted) {
          await _showStatusDialog(
            context: context,
            isSuccess: true,
            title: "Deleted!",
            message: "Registration has been deleted successfully.",
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
        }
      }
    }
  }

  void _showActionSheet(String docId, Map<String, dynamic> data) {
    if (widget.isLocked) return;
    final bool isCountOnly = data['isCountOnly'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Registration Actions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_rounded, color: Colors.blue.shade700),
              ),
              title: Text(
                'Edit Details',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showEditBottomSheet(docId, data);
              },
            ),
            if (isCountOnly) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    color: Colors.orange.shade700,
                  ),
                ),
                title: Text(
                  'Enter Member Details',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentRegistrationForm(
                        programId: widget.programId,
                        programName: widget.programName,
                        convertToDetailedDocId: docId,
                        initialCount: data['studentCount'],
                      ),
                    ),
                  );
                },
              ),
            ],
            if (!widget.isLocked)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                  ),
                ),
                title: Text(
                  'Delete Registration',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteRegistration(docId);
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_circle_rounded,
                  color: Colors.green.shade700,
                ),
              ),
              title: Text(
                'Register Another',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentRegistrationForm(
                      programId: widget.programId,
                      programName: widget.programName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusDialog({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final color = isSuccess ? const Color(0xFF22C55E) : Colors.red;
        final icon = isSuccess
            ? Icons.check_circle_rounded
            : Icons.error_rounded;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.blueGrey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Great!",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditBottomSheet(String docId, Map<String, dynamic> data) {
    if (widget.isLocked) return;
    final bool isCountOnly = data['isCountOnly'] == true;

    final nameController = TextEditingController(
      text: data['studentName']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: data['studentPhone']?.toString() ?? '',
    );
    final countController = TextEditingController(
      text: (data['studentCount'] ?? 1).toString(),
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
                isCountOnly ? 'Edit Member Count' : 'Edit Member',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 16),
              if (isCountOnly)
                TextField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Number of Members',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.people_alt_rounded),
                  ),
                )
              else ...[
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
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (!isCountOnly && nameController.text.isEmpty) return;
                        if (isCountOnly && countController.text.isEmpty) return;

                        setState(() => _isSaving = true);

                        try {
                          final Map<String, dynamic> updateData = {};
                          if (isCountOnly) {
                            updateData['studentCount'] =
                                int.tryParse(countController.text) ?? 1;
                          } else {
                            updateData['studentName'] = nameController.text
                                .trim();
                            updateData['studentPhone'] = phoneController.text
                                .trim();
                          }

                          await FirebaseFirestore.instance
                              .collection('program_registrations')
                              .doc(docId)
                              .update(updateData);

                          if (mounted) {
                            Navigator.pop(ctx);
                            await _showStatusDialog(
                              context: context,
                              isSuccess: true,
                              title: "Updated!",
                              message:
                                  "Registration details updated successfully.",
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.programName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade700],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final bool isCountOnly = data['isCountOnly'] == true;
              final int studentCount = data['studentCount'] ?? 1;

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
                  leading: CircleAvatar(
                    backgroundColor: isCountOnly
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    child: Icon(
                      isCountOnly ? Icons.groups_rounded : Icons.person_rounded,
                      color: isCountOnly
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                  title: Text(
                    isCountOnly
                        ? '$studentCount Member${studentCount == 1 ? '' : 's'} (Count Only)'
                        : (data['studentName'] ?? 'Unknown'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isCountOnly
                        ? 'No details provided'
                        : (data['studentPhone'] ?? 'No Phone'),
                    style: GoogleFonts.poppins(),
                  ),
                  trailing: widget.isLocked
                      ? const Icon(Icons.lock, color: Colors.grey)
                      : IconButton(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.blue.shade900,
                          ),
                          onPressed: () => _showActionSheet(doc.id, data),
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
