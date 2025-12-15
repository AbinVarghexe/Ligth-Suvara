import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminProgramManager extends StatefulWidget {
  const AdminProgramManager({super.key});

  @override
  State<AdminProgramManager> createState() => _AdminProgramManagerState();
}

class _AdminProgramManagerState extends State<AdminProgramManager> {
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  // Track if we are editing
  String? _editingDocId;

  void _saveProgram() async {
    if (_nameController.text.trim().isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End Date must be after Start Date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'name': _nameController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'isActive': true,
      };

      if (_editingDocId == null) {
        // Create new
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('programs').add(data);
      } else {
        // Update existing
        await FirebaseFirestore.instance
            .collection('programs')
            .doc(_editingDocId)
            .update(data);
      }

      if (mounted) {
        setState(() {
          _nameController.clear();
          _startDate = null;
          _endDate = null;
          _editingDocId = null;
          _isLoading = false;
        });
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editingDocId == null
                  ? 'Program Created Successfully'
                  : 'Program Updated Successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showProgramDialog({
    String? docId,
    String? currentName,
    DateTime? currentStart,
    DateTime? currentEnd,
  }) {
    // Initialize state for the dialog
    _editingDocId = docId;
    _nameController.text = currentName ?? '';
    _startDate = currentStart;
    _endDate = currentEnd;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              _editingDocId == null ? 'Create New Program' : 'Edit Program',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Program Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      _startDate == null
                          ? 'Select Start Date'
                          : 'Start: ${DateFormat('yyyy-MM-dd').format(_startDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setStateDialog(() => _startDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      _endDate == null
                          ? 'Select End Date'
                          : 'End: ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setStateDialog(() => _endDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _editingDocId = null;
                  _nameController.clear();
                  _startDate = null;
                  _endDate = null;
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        _saveProgram();
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_editingDocId == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteProgram(String docId) async {
    // Optional: Add confirmation dialog before delete
    await FirebaseFirestore.instance.collection('programs').doc(docId).update({
      'isActive': false,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program archived')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Programs',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProgramDialog(),
        label: const Text('New Program'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('programs')
            .where('isActive', isEqualTo: true)
            // Avoid Firestore orderBy so older docs without startDate still appear; sort client-side.
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active programs found.'));
          }

          final docs = snapshot.data!.docs.toList();
          // Sort by startDate descending when available; keep nulls last.
          docs.sort((a, b) {
            final aStart =
                (a.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
            final bStart =
                (b.data() as Map<String, dynamic>)['startDate'] as Timestamp?;
            if (aStart == null && bStart == null) return 0;
            if (aStart == null) return 1;
            if (bStart == null) return -1;
            return bStart.toDate().compareTo(aStart.toDate());
          });
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unnamed';
              final start = (data['startDate'] as Timestamp).toDate();
              final end = (data['endDate'] as Timestamp).toDate();
            final now = DateTime.now();
            final bool isExpired = end.isBefore(now);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                  '${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isExpired ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isExpired
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Text(
                        isExpired ? 'Expired' : 'Active',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isExpired
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _showProgramDialog(
                            docId: docs[index].id,
                            currentName: name,
                            currentStart: start,
                            currentEnd: end,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteProgram(docs[index].id),
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
