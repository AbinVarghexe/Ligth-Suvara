import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sundayschool_app/animator/student_registration_form.dart';

class RegistrationDashboard extends StatefulWidget {
  const RegistrationDashboard({super.key});

  @override
  State<RegistrationDashboard> createState() => _RegistrationDashboardState();
}

class _RegistrationDashboardState extends State<RegistrationDashboard> {
  final String? schoolId = FirebaseAuth.instance.currentUser?.uid;

  void _showModernSnackBar({required String message, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars(); // Clear existing snackbars
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? Colors.green.shade600
            : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (schoolId == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.indigo.shade800],
            ),
          ),
        ),
        title: Text(
          'Active Programs',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('programs')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, programSnapshot) {
          if (programSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!programSnapshot.hasData || programSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active programs found.'));
          }

          // Fetch locked status for this school
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('program_registrations')
                .where('schoolUserId', isEqualTo: schoolId)
                .where('status', isEqualTo: 'locked')
                .snapshots(),
            builder: (context, lockSnapshot) {
              if (lockSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final lockedPrograms =
                  lockSnapshot.data?.docs
                      .map(
                        (doc) =>
                            (doc.data() as Map<String, dynamic>)['programName']
                                as String,
                      )
                      .toSet() ??
                  {};

              final allDocs = programSnapshot.data!.docs;
              final activePrograms = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final start = (data['startDate'] as Timestamp).toDate();
                final end = (data['endDate'] as Timestamp).toDate();
                return now.isAfter(start.subtract(const Duration(days: 1))) &&
                    now.isBefore(end.add(const Duration(days: 1)));
              }).toList();

              if (activePrograms.isEmpty) {
                return const Center(child: Text('No currently open programs.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: activePrograms.length,
                itemBuilder: (context, index) {
                  final doc = activePrograms[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unnamed';
                  final end = (data['endDate'] as Timestamp).toDate();
                  final isLocked = lockedPrograms.contains(name);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.shade50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: isLocked
                            ? () {
                                _showModernSnackBar(
                                  message:
                                      'Registration for $name is locked by the parish.',
                                  isSuccess: false,
                                );
                              }
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        StudentRegistrationForm(
                                          programId: doc.id,
                                          programName: name,
                                        ),
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.indigo.shade900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: Colors.indigo.shade300,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Closes: ${DateFormat('MMM dd, yyyy').format(end)}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.indigo.shade400,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLocked
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isLocked
                                                ? Icons.lock_rounded
                                                : Icons.check_circle_rounded,
                                            size: 14,
                                            color: isLocked
                                                ? Colors.red.shade600
                                                : Colors.green.shade600,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isLocked
                                                ? 'Registration Locked'
                                                : 'Open for Registration',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              color: isLocked
                                                  ? Colors.red.shade700
                                                  : Colors.green.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? Colors.red.shade50
                                      : Colors.indigo.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: isLocked
                                      ? Colors.red.shade300
                                      : Colors.indigo.shade400,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
