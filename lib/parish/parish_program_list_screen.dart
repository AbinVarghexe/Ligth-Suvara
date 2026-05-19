import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ParishProgramListScreen extends StatefulWidget {
  final String schoolId;
  final String programName;
  final List<String> statuses; // Changed from String status

  const ParishProgramListScreen({
    super.key,
    required this.schoolId,
    required this.programName,
    required this.statuses, // Updated constructor
  });

  @override
  State<ParishProgramListScreen> createState() =>
      _ParishProgramListScreenState();
}

class _ParishProgramListScreenState extends State<ParishProgramListScreen> {
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
          'Are you sure you want to delete this registration? This will permanently remove the record and update the counts.',
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
      setState(() => _isSaving = true);
      try {
        await FirebaseFirestore.instance
            .collection('program_registrations')
            .doc(docId)
            .delete();

        if (mounted) {
          _showModernSnackBar(
            message: 'Registration deleted successfully',
            isSuccess: true,
            icon: Icons.delete_outline_rounded,
          );
        }
      } catch (e) {
        if (mounted) {
          _showModernSnackBar(message: 'Error deleting: $e', isSuccess: false);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _updateStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('program_registrations')
          .doc(docId)
          .update({'status': newStatus});

      if (mounted) {
        _showModernSnackBar(
          message: newStatus == 'approved_parish'
              ? 'Approved successfully!'
              : 'Registration rejected',
          isSuccess: newStatus == 'approved_parish',
        );
        await _showStatusDialog(
          context: context,
          isSuccess: newStatus == 'approved_parish',
          title: newStatus == 'approved_parish' ? 'Approved!' : 'Rejected',
          message: newStatus == 'approved_parish'
              ? 'Registration has been approved successfully.'
              : 'Registration has been rejected.',
        );

      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar(message: 'Error: $e', isSuccess: false);
      }
    }
  }

  void _lockProgram() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Lock Program?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will approve all current students and prevent any further registrations from the school for this program. This cannot be undone by the school registration.',
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Lock',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('program_registrations')
          .where('schoolUserId', isEqualTo: widget.schoolId)
          .where('programName', isEqualTo: widget.programName)
          // We lock everything for this program/school pair regardless of current status??
          // Ideally we only lock proper ones, but usually we just lock the whole set.
          // But strict locking might want to respect statuses.
          // Let's just lock all matching ones for now as per previous logic.
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'status': 'locked'});
      }
      await batch.commit();

      if (mounted) {
        _showModernSnackBar(
          message: 'Program Locked Successfully',
          isSuccess: true,
          icon: Icons.lock_outline_rounded,
        );
        await _showStatusDialog(
          context: context,
          isSuccess: true,
          title: 'Program Locked',
          message: 'The program has been locked successfully for this school.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar(message: 'Error: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _unlockProgram() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Unlock Program?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will allow the school to edit registrations for this program again. The status will be set to "Approved".',
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade900,
            ),
            child: Text(
              'Unlock',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('program_registrations')
          .where('schoolUserId', isEqualTo: widget.schoolId)
          .where('programName', isEqualTo: widget.programName)
          .where('status', isEqualTo: 'locked') // Only unlock locked ones
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'status': 'approved_parish'});
      }
      await batch.commit();

      if (mounted) {
        _showModernSnackBar(
          message: 'Program Unlocked Successfully',
          isSuccess: true,
          icon: Icons.lock_open_rounded,
        );
        await _showStatusDialog(
          context: context,
          isSuccess: true,
          title: 'Program Unlocked',
          message: 'The program registrations are now unlocked and editable.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showModernSnackBar(message: 'Error: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showEditBottomSheet(String docId, Map<String, dynamic> data) {
    if (_isSaving) return;
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isCountOnly ? 'Edit Student Count' : 'Edit Registration',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 24),
                if (isCountOnly)
                  _buildTextField(
                    controller: countController,
                    label: 'Number of Students',
                    icon: Icons.groups_rounded,
                    keyboardType: TextInputType.number,
                  )
                else ...[
                  _buildTextField(
                    controller: nameController,
                    label: 'Student Name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final updatedName = nameController.text.trim();
                            final updatedPhone = phoneController.text.trim();
                            final updatedCount = countController.text.trim();

                            if (!isCountOnly &&
                                (updatedName.isEmpty || updatedPhone.isEmpty)) {
                              _showErrorSnackBar('Name and phone are required');
                              return;
                            }
                            if (isCountOnly && updatedCount.isEmpty) {
                              _showErrorSnackBar('Count is required');
                              return;
                            }

                            setModalState(() => _isSaving = true);
                            try {
                              final Map<String, dynamic> updateData = {};
                              if (isCountOnly) {
                                updateData['studentCount'] =
                                    int.tryParse(updatedCount) ?? 1;
                              } else {
                                updateData['studentName'] = updatedName;
                                updateData['studentPhone'] = updatedPhone;
                              }

                              await FirebaseFirestore.instance
                                  .collection('program_registrations')
                                  .doc(docId)
                                  .update(updateData);
                              if (mounted) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                _showModernSnackBar(
                                  message: 'Registration updated successfully',
                                  isSuccess: true,
                                );
                                await _showStatusDialog(
                                  context: context,
                                  isSuccess: true,
                                  title: 'Updated!',
                                  message:
                                      'Registration details updated successfully.',
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                _showModernSnackBar(
                                  message: 'Error: $e',
                                  isSuccess: false,
                                );
                              }
                            } finally {
                              if (mounted) {
                                setModalState(() => _isSaving = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: Colors.blue.shade900, size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade900, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
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
  void _showModernSnackBar({
    required String message,
    required bool isSuccess,
    IconData? icon,
  }) {
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
                icon ??
                    (isSuccess
                        ? Icons.check_rounded
                        : Icons.error_outline_rounded),
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

  void _showErrorSnackBar(String message) {
    _showModernSnackBar(message: message, isSuccess: false);
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('program_registrations')
          .where('schoolUserId', isEqualTo: widget.schoolId)
          .where('status', whereIn: widget.statuses)
          .where('programName', isEqualTo: widget.programName)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.programName)),
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Check if ANY of the displayed docs are locked.
        // If query returns empty (e.g. no registrations found), default to false.
        // Assuming all items for a program/school pair share the same status (which they should).
        final bool isLocked =
            docs.isNotEmpty && docs.first['status'] == 'locked';

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              widget.programName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
                fontSize: 18,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: Colors.blue.shade900,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (docs.isNotEmpty && !isLocked)
                TextButton.icon(
                  icon: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  label: Text(
                    'Lock',
                    style: GoogleFonts.poppins(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _lockProgram,
                ),
              if (isLocked)
                TextButton.icon(
                  icon: const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                  label: Text(
                    'Unlock',
                    style: GoogleFonts.poppins(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _unlockProgram,
                ),
            ],
          ),
          body: docs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No students found',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isItemLocked = data['status'] == 'locked';
                    final bool isCountOnly = data['isCountOnly'] == true;
                    final int studentCount = data['studentCount'] ?? 1;

                    final studentName = data['studentName']?.toString() ?? 'U';
                    final initial = studentName.isNotEmpty
                        ? studentName[0].toUpperCase()
                        : '?';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isCountOnly
                                      ? Colors.green.shade50
                                      : Colors.blue.shade50,
                                  child: isCountOnly
                                      ? Icon(
                                          Icons.groups_rounded,
                                          color: Colors.green.shade700,
                                        )
                                      : Text(
                                          initial,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isCountOnly
                                            ? '$studentCount Students (Count Only)'
                                            : studentName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone_android_rounded,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isCountOnly
                                                ? 'No details provided'
                                                : '${data['studentPhone'] ?? 'N/A'}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isItemLocked)
                                  IconButton(
                                    onPressed: () =>
                                        _showEditBottomSheet(doc.id, data),
                                    icon: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.edit_rounded,
                                        size: 18,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  if (!isItemLocked)
                                    IconButton(
                                      onPressed: () =>
                                          _deleteRegistration(doc.id),
                                      icon: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                            if (widget.statuses.contains('pending_parish')) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _updateStatus(doc.id, 'rejected'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        side: BorderSide(
                                          color: Colors.red.shade100,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        backgroundColor: Colors.red.shade50,
                                      ),
                                      child: Text(
                                        'Reject',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _updateStatus(
                                        doc.id,
                                        'approved_parish',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'Approve',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
