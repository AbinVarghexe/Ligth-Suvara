import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sundayschool_app/animator/student_registration_form.dart';

class RegistrationDashboard extends StatelessWidget {
  const RegistrationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Active Programs',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('programs')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active programs found.'));
          }

          // Filter locally for date range if needed (or assume admin manages isActive correctly)
          // But requirement says: startDate <= now <= endDate
          final allDocs = snapshot.data!.docs;
          final activePrograms = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final start = (data['startDate'] as Timestamp).toDate();
            final end = (data['endDate'] as Timestamp).toDate();
            // Check if now is between start and end (inclusive-ish)
            return now.isAfter(start.subtract(const Duration(days: 1))) &&
                now.isBefore(end.add(const Duration(days: 1)));
          }).toList();

          if (activePrograms.isEmpty) {
            return const Center(child: Text('No currently open programs.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activePrograms.length,
            itemBuilder: (context, index) {
              final doc = activePrograms[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unnamed';
              final end = (data['endDate'] as Timestamp).toDate();

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentRegistrationForm(
                          programId: doc.id,
                          programName: name,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Closes: ${DateFormat('MMM dd, yyyy').format(end)}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'Open for Registration',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
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
