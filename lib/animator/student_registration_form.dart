import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart';

class StudentRegistrationForm extends StatefulWidget {
  final String programId;
  final String programName;
  final String? convertToDetailedDocId;
  final int? initialCount;

  const StudentRegistrationForm({
    super.key,
    required this.programId,
    required this.programName,
    this.convertToDetailedDocId,
    this.initialCount,
  });

  @override
  State<StudentRegistrationForm> createState() =>
      _StudentRegistrationFormState();
}

class _StudentRegistrationFormState extends State<StudentRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  // Replaced single controllers with a list of entries
  final List<Map<String, TextEditingController>> _studentEntries = [];
  final TextEditingController _countController = TextEditingController();

  bool _isCountOnly = false;
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
    if (widget.convertToDetailedDocId != null && widget.initialCount != null) {
      _isCountOnly = false;
      _countController.text = widget.initialCount.toString();
      _updateStudentEntriesCount(widget.initialCount.toString());
    }
    _countController.addListener(
      () => _updateStudentEntriesCount(_countController.text),
    );
    _loadContext();
    _checkLockStatus();
  }

  void _updateStudentEntriesCount(String value) {
    if (_isCountOnly) return;

    final count = int.tryParse(value) ?? 0;
    if (count < 0) return;

    setState(() {
      if (count > _studentEntries.length) {
        for (int i = _studentEntries.length; i < count; i++) {
          _studentEntries.add({
            'name': TextEditingController(),
            'phone': TextEditingController(),
            'address': TextEditingController(),
            'studentClass': TextEditingController(),
          });
        }
      } else if (count < _studentEntries.length) {
        for (int i = _studentEntries.length - 1; i >= count; i--) {
          final entry = _studentEntries[i];
          entry['name']?.dispose();
          entry['phone']?.dispose();
          entry['address']?.dispose();
          entry['studentClass']?.dispose();
          _studentEntries.removeAt(i);
        }
      }
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

      if (_isCountOnly) {
        final countStr = _countController.text.trim();
        final count = int.tryParse(countStr) ?? 0;
        if (count <= 0) return; // Should be handled by form validation

        final docRef = collection.doc();
        batch.set(docRef, {
          'programId': widget.programId,
          'programName': widget.programName,
          'schoolUserId': user.uid,
          'parishUserId': _parishUserId,
          'parishName': _schoolDisplayName ?? _schoolName,
          'studentCount': count,
          'isCountOnly': true,
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'pending_parish',
          if (_schoolName != null) 'schoolName': _schoolName,
        });
      } else {
        for (final entry in _studentEntries) {
          final name = entry['name']!.text.trim();
          final phone = entry['phone']!.text.trim();
          final address = entry['address']!.text.trim();
          final studentClass = entry['studentClass']!.text.trim();

          final docRef = collection.doc();
          batch.set(docRef, {
            'programId': widget.programId,
            'programName': widget.programName,
            'schoolUserId': user.uid,
            'parishUserId': _parishUserId,
            'parishName': _schoolDisplayName ?? _schoolName,
            'studentName': name,
            'studentPhone': phone,
            'studentAddress': address.isEmpty ? null : address,
            'studentClass': studentClass.isEmpty ? null : studentClass,
            'isCountOnly': false,
            'submittedAt': FieldValue.serverTimestamp(),
            'status': 'pending_parish',
            if (_schoolName != null) 'schoolName': _schoolName,
          });
        }
      }

      if (widget.convertToDetailedDocId != null && !_isCountOnly) {
        final convertDocRef = collection.doc(widget.convertToDetailedDocId);
        batch.delete(convertDocRef);
      }

      await batch.commit();

      if (mounted) {
        await _showStatusDialog(
          context: context,
          isSuccess: true,
          title: "Registration Successful!",
          message: _isCountOnly
              ? 'Successfully registered ${_countController.text.trim()} students!'
              : 'Successfully registered ${_studentEntries.length} students!',
        );
        if (mounted) Navigator.pop(context);
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

  @override
  void dispose() {
    for (var entry in _studentEntries) {
      entry['name']?.dispose();
      entry['phone']?.dispose();
      entry['address']?.dispose();
      entry['studentClass']?.dispose();
    }
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'Register Student',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.indigo.shade800],
            ),
          ),
        ),
        foregroundColor: Colors.white,
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

                    const SizedBox(height: 20),

                    // --- SEGMENTED CONTROL TOGGLE ---
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        children: [
                          AnimatedAlign(
                            alignment: Alignment(_isCountOnly ? 1.0 : -1.0, 0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            child: Container(
                              width:
                                  (MediaQuery.of(context).size.width - 40) / 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade700,
                                    Colors.indigo.shade800,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.indigo.withAlpha(77),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isCountOnly = false;
                                      _updateStudentEntriesCount(
                                        _countController.text,
                                      );
                                    });
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Center(
                                      child: Text(
                                        'Detailed Entry',
                                        style: GoogleFonts.poppins(
                                          color: !_isCountOnly
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _isCountOnly = true),
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Center(
                                      child: Text(
                                        'Count Only',
                                        style: GoogleFonts.poppins(
                                          color: _isCountOnly
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // --- FORM UI ---
                    _buildCountInput(),
                    if (!_isCountOnly && _studentEntries.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildDetailedEntry(),
                    ],

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed:
                          (_isSubmitting || _parishUserId == null || _isLoading)
                          ? null
                          : _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            Colors.transparent, // handeled by gradient
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade600,
                              Colors.indigo.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          height: 56, // Enforce min height
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
                                  _isCountOnly
                                      ? 'Submit Count Registration'
                                      : 'Submit Registrations (${_studentEntries.length})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCountInput() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          Icon(Icons.groups_rounded, size: 60, color: Colors.blue.shade900),
          const SizedBox(height: 16),
          Text(
            'Total Students',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the total number of students participating',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _countController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
            decoration: InputDecoration(
              hintText: '0',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              fillColor: Colors.grey.shade50,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Enter count';
              final num = int.tryParse(val.trim());
              if (num == null || num <= 0) return 'Must be greater than 0';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedEntry() {
    return Column(
      children: [
        ..._studentEntries.asMap().entries.map((element) {
          final index = element.key;
          final entry = element.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Student ${index + 1}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ),
                    // Removed individual delete button; count controls size.
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
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Name Required'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: entry['phone'],
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: const Icon(
                            Icons.phone_android_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          fillColor: Colors.grey.shade50,
                          filled: true,
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Phone Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: entry['studentClass'],
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Class',
                          prefixIcon: const Icon(
                            Icons.school_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          fillColor: Colors.grey.shade50,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: entry['address'],
                  keyboardType: TextInputType.streetAddress,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.home_work_outlined),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    fillColor: Colors.grey.shade50,
                    filled: true,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
