import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class MarkEntryScreen extends StatefulWidget {
  final String unitId;
  final String parish;
  final String sundaySchool;
  final String schoolId;
  final String? assignmentYear;

  const MarkEntryScreen({
    super.key,
    required this.unitId,
    required this.parish,
    required this.sundaySchool,
    required this.schoolId,
    this.assignmentYear,
  });

  @override
  State<MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends State<MarkEntryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final Map<String, int?> _marks = {};
  final Map<String, String> _textValues = {};
  String _remarks = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLocked = false;

  List<QueryDocumentSnapshot> _questions = [];
  String? _pdfUrl;
  String _animatorName = 'Unknown Animator';
  String _docId = '';
  String _currentYear = '';

  @override
  void initState() {
    super.initState();
    // Use the assigned year if available, otherwise fallback to current year
    final year = widget.assignmentYear ?? DateTime.now().year.toString();
    _currentYear = year;
    _docId = '${widget.schoolId}_$year';

    _fetchData();
    _fetchAnimatorName();
  }

  Future<void> _fetchAnimatorName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _animatorName =
                  data?['name'] ?? data?['schoolName'] ?? 'Unknown Animator';
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching animator name: $e");
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final questionsSnapshot = await _firestore
          .collection('questions')
          .orderBy('order')
          .get();
      _questions = questionsSnapshot.docs;

      // Use class variables initialized in initState
      final markDoc = await _firestore.collection('marks').doc(_docId).get();

      if (markDoc.exists) {
        final data = markDoc.data();
        if (data != null) {
          _isLocked = data['locked'] ?? false;
          final savedMarks = data['marks'] as Map<String, dynamic>?;
          if (savedMarks != null) {
            savedMarks.forEach((key, value) {
              if (value is int) {
                _marks[key] = value;
              }
            });
          }
          final savedTextValues = data['textValues'] as Map<String, dynamic>?;
          if (savedTextValues != null) {
            savedTextValues.forEach((key, value) {
              if (value is String) {
                _textValues[key] = value;
              }
            });
          }
          final savedRemarks = data['remarks'];
          if (savedRemarks is String) {
            _remarks = savedRemarks;
          }
          _pdfUrl = data['pdfUrl'];
          _animatorName = data['animatorName'] ?? _animatorName;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, Map<String, dynamic>> _groupQuestionsByPart(
    List<QueryDocumentSnapshot> questions,
  ) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (var doc in questions) {
      final data = doc.data() as Map<String, dynamic>;
      final part = data['part']?.toString() ?? '';
      final partTitle = data['partTitle']?.toString() ?? '';

      if (!grouped.containsKey(part)) {
        grouped[part] = {
          'title': partTitle,
          'questions': <QueryDocumentSnapshot>[],
        };
      } else if ((grouped[part]!['title'] as String).isEmpty &&
          partTitle.isNotEmpty) {
        grouped[part]!['title'] = partTitle;
      }
      (grouped[part]!['questions'] as List<QueryDocumentSnapshot>).add(doc);
    }

    // Sort parts (I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII, XIII, XIV, XV, XVI, XVII, XVIII, XIX, XX)
    final List<String> partOrder = [
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
      'XI',
      'XII',
      'XIII',
      'XIV',
      'XV',
      'XVI',
      'XVII',
      'XVIII',
      'XIX',
      'XX',
    ];
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        int idxA = partOrder.indexOf(a);
        int idxB = partOrder.indexOf(b);
        if (idxA == -1 && idxB == -1) return a.compareTo(b);
        if (idxA == -1) return 1;
        if (idxB == -1) return -1;
        return idxA.compareTo(idxB);
      });

    final Map<String, Map<String, dynamic>> sortedGrouped = {};
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    return sortedGrouped;
  }

  Future<void> _submitMarks() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final animatorId = FirebaseAuth.instance.currentUser?.uid;

      await _firestore.collection('marks').doc(_docId).set({
        'unitId': widget.unitId,
        'schoolId': widget.schoolId,
        'parish': widget.parish,
        'sundaySchool': widget.sundaySchool,
        'animatorId': animatorId,
        'animatorName': _animatorName,
        'year': _currentYear,
        'marks': _marks,
        'textValues': _textValues,
        'remarks': _remarks,
        'pdfUrl': _pdfUrl,
        'locked': true,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isLocked = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marks submitted successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting marks: $e')));
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _uploadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isLoading = true);

        final fileName = result.files.first.name;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('marks_pdfs')
            .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

        UploadTask uploadTask;

        if (result.files.first.bytes != null) {
          uploadTask = storageRef.putData(result.files.first.bytes!);
        } else if (result.files.first.path != null) {
          uploadTask = storageRef.putFile(File(result.files.first.path!));
        } else {
          throw Exception("No file data found");
        }

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          _pdfUrl = downloadUrl;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PDF Uploaded Successfully!'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark Entry',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              widget.parish,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50.withOpacity(0.5), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.blue.shade900,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading questions...',
                      style: GoogleFonts.inter(
                        color: Colors.blue.shade900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                  children: [
                    if (_isLocked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.shade100.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.amber.shade800,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Submission Locked',
                                    style: GoogleFonts.poppins(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'These marks have been submitted and cannot be edited.',
                                    style: GoogleFonts.inter(
                                      color: Colors.amber.shade900.withOpacity(
                                        0.8,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Questions Section
                    Text(
                      'Questions',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._groupQuestionsByPart(_questions).entries.map((
                      partEntry,
                    ) {
                      final part = partEntry.key;
                      final partData = partEntry.value;
                      final partTitle = partData['title'] as String;
                      final questions =
                          partData['questions'] as List<QueryDocumentSnapshot>;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (part.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 16,
                                left: 4,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade900,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.shade900
                                              .withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'Part $part',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (partTitle.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        partTitle,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ...questions.asMap().entries.map((qEntry) {
                            final doc = qEntry.value;
                            // Find original index for question numbering if needed,
                            // or just use 1, 2, 3... within the part.
                            // The image shows 1, 2, 3... within each part.
                            final index = qEntry.key;
                            final data = doc.data() as Map<String, dynamic>;
                            final questionText = data['text'] ?? 'Question';
                            final int? maxMark = data['maxMark'];
                            final qId = doc.id;
                            final bool isMandatory =
                                data['isMandatory'] ?? true;
                            final bool isReadOnly = data['isReadOnly'] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
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
                                              questionText,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey.shade800,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isMandatory == false
                                                    ? Colors.orange.shade50
                                                    : Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isMandatory == false
                                                    ? 'Optional'
                                                    : 'Mandatory',
                                                style: GoogleFonts.inter(
                                                  color: isMandatory == false
                                                      ? Colors.orange.shade800
                                                      : Colors.blue.shade800,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (data['subFields'] == null ||
                                      (data['subFields'] as List).isEmpty) ...[
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      key: ValueKey(qId),
                                      initialValue: _marks[qId]?.toString(),
                                      style: GoogleFonts.inter(fontSize: 16),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: isMandatory
                                            ? 'Mark ${maxMark != null ? '(Max: $maxMark)' : ''} *'
                                            : 'Mark ${maxMark != null ? '(Max: $maxMark)' : ''}',
                                        labelStyle: GoogleFonts.inter(
                                          color: Colors.grey.shade600,
                                        ),
                                        hintText: '0',
                                        prefixIcon: Icon(
                                          Icons.grade_rounded,
                                          color: Colors.blue.shade700,
                                          size: 20,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.blue.shade700,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 20,
                                            ),
                                      ),
                                      enabled: !_isLocked,
                                      validator: (value) {
                                        if (isMandatory &&
                                            (value == null || value.isEmpty)) {
                                          return 'Please enter a mark';
                                        }
                                        if (value == null || value.isEmpty) {
                                          return null;
                                        }
                                        final mark = int.tryParse(value);
                                        if (mark == null) {
                                          return 'Invalid number';
                                        }
                                        if (maxMark != null &&
                                            (mark < 0 || mark > maxMark)) {
                                          return 'Max mark is $maxMark';
                                        }
                                        return null;
                                      },
                                      onChanged: (value) {
                                        final mark = int.tryParse(value);
                                        if (mark != null) {
                                          _marks[qId] = mark;
                                        } else if (value.isEmpty) {
                                          _marks.remove(qId);
                                        }
                                      },
                                    ),
                                  ],
                                  if (data['subFields'] != null &&
                                      (data['subFields'] as List)
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    ...(data['subFields'] as List).asMap().entries.map((
                                      subEntry,
                                    ) {
                                      final subIndex = subEntry.key;
                                      final subField =
                                          subEntry.value
                                              as Map<String, dynamic>;
                                      final subText = subField['text'] ?? '';
                                      final subMaxMark =
                                          subField['maxMark'] ?? 0;
                                      final String subAdminText =
                                          (subField['adminText'] ?? '')
                                              .toString();
                                      final subId = '${qId}_sub_$subIndex';

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                          left: 16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (subAdminText.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                  left: 8,
                                                ),
                                                child: Text(
                                                  subAdminText,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            if (isReadOnly == false) ...[
                                              TextFormField(
                                                initialValue:
                                                    _textValues[subId],
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: subText.isNotEmpty
                                                      ? 'Details $subText'
                                                      : 'Details',
                                                  prefixIcon: Icon(
                                                    Icons.info_outline,
                                                    color: Colors.blue.shade300,
                                                    size: 16,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      Colors.grey.shade50,
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                        ),
                                                      ),
                                                ),
                                                enabled: !_isLocked,
                                                onChanged: (value) {
                                                  if (value.trim().isEmpty) {
                                                    _textValues.remove(subId);
                                                  } else {
                                                    _textValues[subId] = value;
                                                  }
                                                },
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            TextFormField(
                                              key: ValueKey(subId),
                                              initialValue: _marks[subId]
                                                  ?.toString(),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: isMandatory
                                                    ? 'Mark ${subMaxMark != null && subMaxMark > 0 ? '(Max: $subMaxMark)' : '(Unlimited)'} *'
                                                    : 'Mark ${subMaxMark != null && subMaxMark > 0 ? '(Max: $subMaxMark)' : '(Unlimited)'}',
                                                labelStyle: GoogleFonts.inter(
                                                  color: Colors.grey.shade600,
                                                ),
                                                hintText: '0',
                                                prefixIcon: Icon(
                                                  Icons
                                                      .subdirectory_arrow_right,
                                                  color: Colors.blue.shade300,
                                                  size: 18,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade200,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Colors
                                                            .blue
                                                            .shade700,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                filled: true,
                                                fillColor: Colors.grey.shade50,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16,
                                                    ),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                              enabled: !_isLocked,
                                              validator: (value) {
                                                if (isMandatory &&
                                                    (value == null ||
                                                        value.isEmpty)) {
                                                  return 'Required';
                                                }
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return null;
                                                }
                                                final mark = int.tryParse(
                                                  value,
                                                );
                                                if (mark == null) {
                                                  return 'Invalid';
                                                }
                                                if (subMaxMark != null &&
                                                    (mark < 0 ||
                                                        mark > subMaxMark)) {
                                                  return 'Max $subMaxMark';
                                                }
                                                return null;
                                              },
                                              onChanged: (value) {
                                                final mark = int.tryParse(
                                                  value,
                                                );
                                                if (mark != null) {
                                                  _marks[subId] = mark;
                                                } else if (value.isEmpty) {
                                                  _marks.remove(subId);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    }),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.comment_rounded,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'General Remarks',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: _remarks,
                            style: GoogleFonts.inter(fontSize: 14),
                            maxLines: 4,
                            maxLength: 500,
                            decoration: InputDecoration(
                              hintText:
                                  'Add overall comments, feedback, or notes regarding this student...',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.grey.shade400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade700,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                            enabled: !_isLocked,
                            onChanged: (value) {
                              _remarks = value;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PDF Upload Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.file_present_rounded,
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Upload PDF',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    Text(
                                      'Upload verified PDF',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _pdfUrl != null
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _pdfUrl != null
                                    ? Colors.green.shade200
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _pdfUrl != null
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  color: _pdfUrl != null
                                      ? Colors.green.shade600
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _pdfUrl != null
                                        ? 'PDF Uploaded Successfully'
                                        : 'No PDF Uploaded',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: _pdfUrl != null
                                          ? Colors.green.shade800
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isLocked) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _uploadPdf,
                                icon: const Icon(Icons.cloud_upload_rounded),
                                label: Text(
                                  _pdfUrl != null ? 'Change PDF' : 'Upload PDF',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: BorderSide(color: Colors.blue.shade700),
                                  foregroundColor: Colors.blue.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    if (!_isLocked)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade800,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade900.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitMarks,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'SUBMIT MARKS',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
