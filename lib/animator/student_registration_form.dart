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
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _parishUserId;
  String? _schoolUserId;
  String? _schoolName;
  String? _schoolDisplayName;

  @override
  void initState() {
    super.initState();
    _loadContext();
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
      await FirebaseFirestore.instance.collection('program_registrations').add({
        'programId': widget.programId,
        'programName': widget.programName,
        'schoolUserId': user.uid,
        'parishUserId': _parishUserId,
        'parishName': _schoolDisplayName ?? _schoolName,
        'studentName': _nameController.text.trim(),
        'studentPhone': _phoneController.text.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending_parish',
        if (_schoolName != null) 'schoolName': _schoolName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Submitted Successfully!'),
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
    _nameController.dispose();
    _phoneController.dispose();
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
                                  Expanded(
                                    child: Text(
                                      "No linked parish found. Ask an admin to set a parish for this school before submitting.",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    (_parishUserId != null &&
                                        _parishUserId!.length > 20)
                                    ? Colors.blue.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      (_parishUserId != null &&
                                          _parishUserId!.length > 20)
                                      ? Colors.blue.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.church,
                                    color:
                                        (_parishUserId != null &&
                                            _parishUserId!.length > 20)
                                        ? Colors.blue.shade800
                                        : Colors.red.shade800,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Linked Parish User",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color:
                                                (_parishUserId != null &&
                                                    _parishUserId!.length > 20)
                                                ? Colors.blue.shade800
                                                : Colors.red.shade900,
                                          ),
                                        ),
                                        Text(
                                          _parishUserId!,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color:
                                                (_parishUserId != null &&
                                                    _parishUserId!.length > 20)
                                                ? Colors.blue.shade900
                                                : Colors.red.shade900,
                                          ),
                                        ),
                                        // DEBUG INFO FOR USER
                                        if (_parishUserId != null &&
                                            _parishUserId!.length < 20)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Text(
                                              "WARNING: This looks like a Name, not an ID! Linkage is broken. Ask Admin to update your 'parishId' field with the Parish User UID.",
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (_schoolName != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            "School: $_schoolName",
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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
                            ),
                    ),

                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Student Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Parent Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Phone is required'
                          : null,
                    ),
                    const SizedBox(height: 40),
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
                              'Submit Registration',
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
