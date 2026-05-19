import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminPublicProgramsManager extends StatefulWidget {
  const AdminPublicProgramsManager({super.key});

  @override
  State<AdminPublicProgramsManager> createState() => _AdminPublicProgramsManagerState();
}

class _AdminPublicProgramsManagerState extends State<AdminPublicProgramsManager> {
  final _nameController = TextEditingController();
  final _regInfoController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  String? _editingDocId;

  @override
  void dispose() {
    _nameController.dispose();
    _regInfoController.dispose();
    super.dispose();
  }

  void _saveProgram() async {
    if (_nameController.text.trim().isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all mandatory fields')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End Date must be after Start Date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'regInfo': _regInfoController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_editingDocId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('public_registration_programs').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('public_registration_programs')
            .doc(_editingDocId)
            .update(data);
      }

      if (mounted) {
        _resetForm();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingDocId == null ? 'Public Program Created' : 'Public Program Updated'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _resetForm() {
    _nameController.clear();
    _regInfoController.clear();
    _startDate = null;
    _endDate = null;
    _editingDocId = null;
    _isLoading = false;
  }

  void _showProgramDialog({
    String? docId,
    String? currentName,
    String? currentInfo,
    DateTime? currentStart,
    DateTime? currentEnd,
  }) {
    _editingDocId = docId;
    _nameController.text = currentName ?? '';
    _regInfoController.text = currentInfo ?? '';
    _startDate = currentStart;
    _endDate = currentEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _editingDocId == null ? 'Create Public Program' : 'Edit Public Program',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                ),
                const SizedBox(height: 8),
                Text(
                  'This program will appear on the Login Screen banner for public registration.',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                _buildField(
                  controller: _nameController,
                  label: 'Program Name',
                  icon: Icons.campaign_rounded,
                  hint: 'e.g., Summer Camp 2026',
                ),
                const SizedBox(height: 20),
                _buildDateSelector(
                  label: 'Registration Start',
                  date: _startDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setStateDialog(() => _startDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                _buildDateSelector(
                  label: 'Registration End',
                  date: _endDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setStateDialog(() => _endDate = picked);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Program Information (Optional)',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.teal.shade800),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: TextFormField(
                    controller: _regInfoController,
                    maxLines: 4,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add details to help people understand what this program is about...',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProgram,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_editingDocId == null ? 'Create Program' : 'Update Program', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String label, required IconData icon, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.teal.shade700, size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector({required String label, required DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: Colors.teal.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                  Text(
                    date == null ? 'Select Date' : DateFormat('MMM dd, yyyy').format(date),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: date == null ? Colors.grey.shade400 : Colors.grey.shade900),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _deleteProgram(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Program?'),
        content: const Text('This will remove the program from public view.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('public_registration_programs').doc(docId).update({'isActive': false});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Program archived')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Public Programs', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProgramDialog(),
        label: Text('New Public Program', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('public_registration_programs')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No public programs active', style: GoogleFonts.poppins(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unnamed';
              final info = data['regInfo'] ?? '';
              final start = (data['startDate'] as Timestamp).toDate();
              final end = (data['endDate'] as Timestamp).toDate();

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [BoxShadow(color: Colors.teal.shade900.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal.shade900)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.teal),
                            onPressed: () => _showProgramDialog(
                              docId: docs[index].id,
                              currentName: name,
                              currentInfo: info,
                              currentStart: start,
                              currentEnd: end,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteProgram(docs[index].id),
                          ),
                        ],
                      ),
                      if (info.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(info, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.date_range_rounded, size: 16, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                          ),
                        ],
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
}
