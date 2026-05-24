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
  final List<Map<String, TextEditingController>> _studentEntries = [];
  final TextEditingController _countController = TextEditingController();

  bool _isCountOnly = false;
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _parishUserId;
  String? _schoolName;
  String? _schoolDisplayName;

  bool _isLocked = false;

  // Dynamic config fields
  String _targetAudience = 'student';
  List<CustomField> _activeFields = [];

  @override
  void initState() {
    super.initState();
    if (widget.convertToDetailedDocId != null && widget.initialCount != null) {
      _isCountOnly = false;
      _countController.text = widget.initialCount.toString();
    }
    _countController.addListener(
      () => _updateStudentEntriesCount(_countController.text),
    );
    _loadProgramAndContext();
    _checkLockStatus();
  }

  void _updateStudentEntriesCount(String value) {
    if (_isCountOnly) return;
    if (_activeFields.isEmpty) return;

    final count = int.tryParse(value) ?? 0;
    if (count < 0) return;

    setState(() {
      if (count > _studentEntries.length) {
        for (int i = _studentEntries.length; i < count; i++) {
          final Map<String, TextEditingController> entry = {};
          for (final field in _activeFields) {
            entry[field.id] = TextEditingController();
          }
          _studentEntries.add(entry);
        }
      } else if (count < _studentEntries.length) {
        for (int i = _studentEntries.length - 1; i >= count; i--) {
          final entry = _studentEntries[i];
          for (var controller in entry.values) {
            controller.dispose();
          }
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

  Future<void> _loadProgramAndContext() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userData = Provider.of<UserDataProvider>(
      context,
      listen: false,
    ).userData;

    try {
      // 1. Fetch Program details to get targetAudience and fields config
      final programDoc = await FirebaseFirestore.instance
          .collection('programs')
          .doc(widget.programId)
          .get();

      if (programDoc.exists) {
        final data = programDoc.data();
        if (data != null) {
          final audience = data['targetAudience'] ?? 'student';
          _targetAudience = audience == 'teacher' ? 'teacher' : 'student';

          final fieldsKey = _targetAudience == 'teacher' ? 'teacherFields' : 'studentFields';
          final List<dynamic>? rawFields = data[fieldsKey];
          if (rawFields != null && rawFields.isNotEmpty) {
            _activeFields = rawFields.map((f) => CustomField.fromMap(Map<String, dynamic>.from(f as Map))).toList();
          }
        }
      }

      // Fallback fields in case configuration is not present
      if (_activeFields.isEmpty) {
        _activeFields = [
          CustomField(id: 'name', name: 'Name', type: 'text', isMandatory: true),
          CustomField(id: 'phone', name: 'Phone', type: 'phone', isMandatory: true),
          CustomField(id: 'studentClass', name: 'Class', type: 'text', isMandatory: false),
          CustomField(id: 'address', name: 'Address', type: 'text', isMandatory: false),
        ];
      }

      // 2. Fetch User/Parish data
      String? parishLink = userData.parishId;

      if (parishLink == null && currentUser != null) {
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
        _schoolName = userData.schoolName ?? userData.schoolDisplayName;
        _schoolDisplayName = userData.schoolDisplayName;
        _isLoading = false;

        // Initialize entries if a count is already set
        if (widget.convertToDetailedDocId != null && widget.initialCount != null) {
          _updateStudentEntriesCount(widget.initialCount.toString());
        } else if (_countController.text.isNotEmpty) {
          _updateStudentEntriesCount(_countController.text);
        }
      });
    } catch (e) {
      debugPrint("Error loading program and context: $e");
      if (_activeFields.isEmpty) {
        _activeFields = [
          CustomField(id: 'name', name: 'Name', type: 'text', isMandatory: true),
          CustomField(id: 'phone', name: 'Phone', type: 'phone', isMandatory: true),
          CustomField(id: 'studentClass', name: 'Class', type: 'text', isMandatory: false),
          CustomField(id: 'address', name: 'Address', type: 'text', isMandatory: false),
        ];
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_countController.text.isNotEmpty) {
            _updateStudentEntriesCount(_countController.text);
          }
        });
      }
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

      final isTeacher = _targetAudience == 'teacher';

      if (_isCountOnly) {
        final countStr = _countController.text.trim();
        final count = int.tryParse(countStr) ?? 0;
        if (count <= 0) return;

        final docRef = collection.doc();
        batch.set(docRef, {
          'programId': widget.programId,
          'programName': widget.programName,
          'schoolUserId': user.uid,
          'parishUserId': _parishUserId,
          'parishName': _schoolDisplayName ?? _schoolName,
          'studentCount': count, // Count remains studentCount for compatibility
          'isCountOnly': true,
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'pending_parish',
          if (_schoolName != null) 'schoolName': _schoolName,
          'type': _targetAudience,
        });
      } else {
        for (final entry in _studentEntries) {
          final Map<String, String> customFieldValues = {};
          for (final field in _activeFields) {
            customFieldValues[field.id] = entry[field.id]?.text.trim() ?? '';
          }

          // Build fallbacks for standard fields to maintain compatibility with dashboard
          String? fallbackName;
          String? fallbackPhone;
          String? fallbackAddress;
          String? fallbackClass;

          for (final field in _activeFields) {
            final val = entry[field.id]?.text.trim() ?? '';
            final fieldNameLower = field.name.toLowerCase();
            final fieldIdLower = field.id.toLowerCase();

            if (fieldIdLower == 'name' || (fallbackName == null && fieldNameLower.contains('name'))) {
              fallbackName = val;
            }
            if (fieldIdLower == 'phone' || field.type == 'phone' || (fallbackPhone == null && (fieldNameLower.contains('phone') || fieldNameLower.contains('mobile') || fieldNameLower.contains('contact')))) {
              fallbackPhone = val;
            }
            if (fieldIdLower == 'address' || (fallbackAddress == null && fieldNameLower.contains('address'))) {
              fallbackAddress = val;
            }
            if (fieldIdLower == 'class' || fieldIdLower == 'studentclass' || (fallbackClass == null && fieldNameLower.contains('class'))) {
              fallbackClass = val;
            }
          }

          final docRef = collection.doc();
          batch.set(docRef, {
            'programId': widget.programId,
            'programName': widget.programName,
            'schoolUserId': user.uid,
            'parishUserId': _parishUserId,
            'parishName': _schoolDisplayName ?? _schoolName,
            'isCountOnly': false,
            'submittedAt': FieldValue.serverTimestamp(),
            'status': 'pending_parish',
            if (_schoolName != null) 'schoolName': _schoolName,
            'type': _targetAudience,
            'customFieldValues': customFieldValues,
            'studentName': fallbackName ?? '',
            'studentPhone': fallbackPhone ?? '',
            if (fallbackAddress != null && fallbackAddress.isNotEmpty) 'studentAddress': fallbackAddress,
            if (fallbackClass != null && fallbackClass.isNotEmpty) 'studentClass': fallbackClass,
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
              ? 'Successfully registered ${_countController.text.trim()} ${isTeacher ? 'teachers' : 'students'}!'
              : 'Successfully registered ${_studentEntries.length} ${isTeacher ? 'teachers' : 'students'}!',
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
                  color: color.withValues(alpha: 0.1),
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
      for (var controller in entry.values) {
        controller.dispose();
      }
    }
    _countController.dispose();
    super.dispose();
  }

  IconData _getFieldIcon(CustomField field) {
    final nameLower = field.name.toLowerCase();
    final idLower = field.id.toLowerCase();
    if (idLower == 'name' || nameLower.contains('name')) {
      return Icons.person_outline;
    } else if (field.type == 'phone' || idLower == 'phone' || nameLower.contains('phone') || nameLower.contains('mobile') || nameLower.contains('contact')) {
      return Icons.phone_android_rounded;
    } else if (idLower == 'class' || idLower == 'studentclass' || nameLower.contains('class') || nameLower.contains('grade')) {
      return Icons.school_rounded;
    } else if (idLower == 'address' || nameLower.contains('address') || nameLower.contains('location') || nameLower.contains('residence')) {
      return Icons.home_work_outlined;
    } else if (field.type == 'number' || nameLower.contains('age') || nameLower.contains('number')) {
      return Icons.numbers_rounded;
    } else if (nameLower.contains('email') || field.type == 'email') {
      return Icons.email_outlined;
    }
    return Icons.edit_note_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _targetAudience == 'teacher';
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'Register ${isTeacher ? 'Teacher' : 'Student'}',
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
                            backgroundColor: Colors.transparent,
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
                              height: 56,
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
                                          : 'Submit ${isTeacher ? 'Teacher' : 'Student'} Registrations (${_studentEntries.length})',
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
    final isTeacher = _targetAudience == 'teacher';
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
            'Total ${isTeacher ? 'Teachers' : 'Students'}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the total number of ${isTeacher ? 'teachers' : 'students'} participating',
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
    final isTeacher = _targetAudience == 'teacher';
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
                        '${isTeacher ? 'Teacher' : 'Student'} ${index + 1}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._activeFields.map((field) {
                  final controller = entry[field.id];
                  if (controller == null) return const SizedBox.shrink();

                  final isPhone = field.type == 'phone' ||
                      field.id.toLowerCase() == 'phone' ||
                      field.name.toLowerCase().contains('phone');
                  final isNumber = field.type == 'number' ||
                      field.name.toLowerCase().contains('age') ||
                      field.name.toLowerCase().contains('number');
                  final isAddress = field.id.toLowerCase() == 'address' ||
                      field.name.toLowerCase().contains('address');

                  String label = field.name;
                  if (field.name.toLowerCase() == 'name') {
                    label = '${isTeacher ? 'Teacher' : 'Student'} Name';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: controller,
                      keyboardType: isPhone
                          ? TextInputType.phone
                          : isNumber
                              ? TextInputType.number
                              : isAddress
                                  ? TextInputType.streetAddress
                                  : TextInputType.text,
                      maxLines: isAddress ? 2 : 1,
                      decoration: InputDecoration(
                        labelText: label,
                        prefixIcon: Icon(_getFieldIcon(field)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: Colors.grey.shade50,
                        filled: true,
                      ),
                      validator: (val) {
                        if (field.isMandatory) {
                          if (val == null || val.trim().isEmpty) {
                            return '$label Required';
                          }
                        }
                        return null;
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class CustomField {
  final String id;
  final String name;
  final String type;
  final bool isMandatory;

  CustomField({
    required this.id,
    required this.name,
    required this.type,
    required this.isMandatory,
  });

  factory CustomField.fromMap(Map<String, dynamic> map) {
    return CustomField(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      isMandatory: map['isMandatory'] == true,
    );
  }
}
