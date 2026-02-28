import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminObserverRemarksViewScreen extends StatelessWidget {
  final String assignmentId;

  const AdminObserverRemarksViewScreen({super.key, required this.assignmentId});

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
          'Observer Submission',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade900, Colors.indigo.shade600],
            ),
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('assignments')
            .doc(assignmentId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Assignment not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final remarks = data['remarks'] ?? '';
          final totalAttendance = data['totalAttendance']?.toString() ?? 'N/A';
          final absentees = data['absentees'] ?? 'None';
          final submittedAt = data['remarksSubmittedAt'] as Timestamp?;
          final observerName = data['teacherName'] ?? 'Unknown';
          final targetSchool = data['targetSchoolName'] ?? 'Unknown School';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(observerName, targetSchool, submittedAt),
                const SizedBox(height: 24),
                _buildDetailCard(
                  title: 'Attendance Metrics',
                  icon: Icons.people_alt_rounded,
                  color: Colors.blue.shade700,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Total Attendance', totalAttendance),
                      const Divider(height: 24),
                      Text(
                        'Absentees',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        absentees,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetailCard(
                  title: 'Observer Remarks',
                  icon: Icons.description_rounded,
                  color: Colors.indigo.shade700,
                  child: Text(
                    remarks.isEmpty ? 'No remarks submitted yet.' : remarks,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.indigo.shade900,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(String name, String school, Timestamp? time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.indigo.shade50,
            child: Icon(Icons.person, color: Colors.indigo.shade700, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
          Text(
            'Observer',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.indigo.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSimpleInfo('Location', school),
              _buildSimpleInfo(
                'Submitted',
                time != null
                    ? DateFormat('MMM dd, hh:mm a').format(time.toDate())
                    : 'Pending',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
          ),
        ),
      ],
    );
  }
}
