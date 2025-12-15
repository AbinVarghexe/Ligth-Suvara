import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart';

class StudentRegistrationForm extends StatefulWidget {
  final String programId;
  final String programName;

  const StudentRegistrationForm({
    super.key,
    required this.programId,
    required this.programName,
  });

  @override
  State<StudentRegistrationForm> createState() =>
      _StudentRegistrationFormState();
}

class _StudentRegistrationFormState extends State<StudentRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  // Replaced single controllers with a list of entries
  final List<Map<String, TextEditingController>> _studentEntries = [];

  // final _nameController = TextEditingController(); // Removed
  // final _phoneController = TextEditingController(); // Removed
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _parishUserId;
  String? _schoolUserId;
  String? _schoolName;
  String? _schoolDisplayName;

  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _addStudentEntry(); // Add initial entry
    _loadContext();
    _checkLockStatus();
  }

  void _addStudentEntry() {
    setState(() {
      _studentEntries.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeStudentEntry(int index) {
    if (_studentEntries.length <= 1) return;
    final entry = _studentEntries[index];
    entry['name']?.dispose();
    entry['phone']?.dispose();
    setState(() {
      _studentEntries.removeAt(index);
    });
  }

  Future<void> _checkLockStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('program_registrations')
          .where('schoolUserId', isEqualTo: user.uid)
          .where('programName', isEqualTo: widget.programName)
          // If *any* registration for this program is marked locked, we consider the program locked.
          .where('status', isEqualTo: 'locked')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        if (mounted) setState(() => _isLocked = true);
      }
    } catch (e) {
      debugPrint("Error checking lock status: $e");
    }
  }

  Future<void> _loadContext() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final provider = Provider.of<UserDataProvider>(
        context,
        listen: false,
      ).userData;
      String? parishLink = provider.parishId;

      // Fallback to Firestore in case provider data is stale
      if (parishLink == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final data = userDoc.data();
        parishLink = data?['parishId'] ?? data?['parish'];
      }

      if (!mounted) return;
      setState(() {
        _parishUserId = parishLink;
        _schoolUserId = currentUser.uid;
        _schoolName = provider.schoolName ?? provider.schoolDisplayName;
        _schoolDisplayName = provider.schoolDisplayName;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading registration context: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_parishUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No parish linked to this school. Please contact admin.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to submit.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection(
        'program_registrations',
      );

      for (final entry in _studentEntries) {
        final name = entry['name']!.text.trim();
        final phone = entry['phone']!.text.trim();

        final docRef = collection.doc();
        batch.set(docRef, {
          'programId': widget.programId,
          'programName': widget.programName,
          'schoolUserId': user.uid,
          'parishUserId': _parishUserId,
          'parishName': _schoolDisplayName ?? _schoolName,
          'studentName': name,
          'studentPhone': phone,
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'pending_parish',
          if (_schoolName != null) 'schoolName': _schoolName,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully registered ${_studentEntries.length} students!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    for (var entry in _studentEntries) {
      entry['name']?.dispose();
      entry['phone']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Register Student',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isLocked
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_person_rounded,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Registration Locked',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The registration for ${widget.programName} has been finalized and locked by the parish.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Go Back',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.programName,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _parishUserId == null
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.link_off,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 12),

                                  Icon(
                                    (_parishUserId != null &&
                                            _parishUserId!.length > 20)
                                        ? Icons.check_circle
                                        : Icons.warning_amber_rounded,
                                    color:
                                        (_parishUserId != null &&
                                            _parishUserId!.length > 20)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    ..._studentEntries.asMap().entries.map((element) {
                      final index = element.key;
                      final entry = element.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Student ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                if (_studentEntries.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeStudentEntry(index),
                                    tooltip: 'Remove Student',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: entry['name'],
                              decoration: InputDecoration(
                                labelText: 'Student Name',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                fillColor: Colors.grey.shade50,
                                filled: true,
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Name Required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: entry['phone'],
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: const Icon(
                                  Icons.phone_android_rounded,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                fillColor: Colors.grey.shade50,
                                filled: true,
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Phone Required'
                                  : null,
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    // Add Button
                    Center(
                      child: TextButton.icon(
                        onPressed: _addStudentEntry,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 24,
                        ),
                        label: Text(
                          'Add Another Student',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          foregroundColor: Colors.blue.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed:
                          (_isSubmitting || _parishUserId == null || _isLoading)
                          ? null
                          : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit Registrations (${_studentEntries.length})',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
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
}
