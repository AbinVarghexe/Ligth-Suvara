import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminPublicRegistrationsViewer extends StatefulWidget {
  const AdminPublicRegistrationsViewer({super.key});

  @override
  State<AdminPublicRegistrationsViewer> createState() => _AdminPublicRegistrationsViewerState();
}

class _AdminPublicRegistrationsViewerState extends State<AdminPublicRegistrationsViewer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Public Registrations',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue.shade900),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('public_registrations')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No registrations yet',
                    style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final regs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: regs.length,
            itemBuilder: (context, index) {
              final data = regs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown';
              final programTitle = data['programTitle'] ?? data['eventTitle'] ?? 'Unknown Program';
              final phone = data['phone'] ?? 'No Phone';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final dateStr = timestamp != null ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp) : 'Unknown date';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    name,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Program: $programTitle',
                        style: GoogleFonts.outfit(color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(phone, style: GoogleFonts.outfit(color: Colors.grey.shade600)),
                          const Spacer(),
                          Text(dateStr, style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _showDetailsDialog(data, regs[index].id),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _confirmDeletion(regs[index].id, name),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDeletion(String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Registration', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete the registration for $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('public_registrations').doc(docId).delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registration deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Registration Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Name', data['name']),
              _buildDetailItem('Phone', data['phone']),
              _buildDetailItem('Email', data['email']),
              _buildDetailItem('Address', data['address']),
              _buildDetailItem('Qualification', data['qualification']),
              _buildDetailItem('Current Status', data['currentStatus']),
              _buildDetailItem('Interested in', data['programTitle'] ?? data['eventTitle']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value?.toString() ?? 'N/A',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
