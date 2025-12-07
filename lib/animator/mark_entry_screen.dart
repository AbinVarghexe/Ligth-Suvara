import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MarkEntryScreen extends StatefulWidget {
  final String unitId;
  final String parish;
  final String sundaySchool;
  final String schoolId; // Added schoolId

  const MarkEntryScreen({
    super.key,
    required this.unitId,
    required this.parish,
    required this.sundaySchool,
    required this.schoolId, // Added required parameter
  });

  @override
  State<MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends State<MarkEntryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final Map<String, int> _marks = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLocked = false;

  List<QueryDocumentSnapshot> _questions = [];
  String? _pdfUrl;
  String _animatorName = 'Unknown Animator';

  @override
  void initState() {
    super.initState();
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
      print("Error fetching animator name: $e");
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final questionsSnapshot = await _firestore
          .collection('questions')
          .orderBy('order')
          .get();
      _questions = questionsSnapshot.docs;

      final currentYear = DateTime.now().year.toString();
      // Use schoolId for persistent key: schoolUserId_Year
      final docId = '${widget.schoolId}_$currentYear';

      final markDoc = await _firestore.collection('marks').doc(docId).get();

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

  Future<void> _submitMarks() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final currentYear = DateTime.now().year.toString();
      // Use schoolId for persistent key: schoolUserId_Year
      final docId = '${widget.schoolId}_$currentYear';
      final animatorId = FirebaseAuth.instance.currentUser?.uid;

      await _firestore.collection('marks').doc(docId).set({
        'unitId': widget.unitId, // Keep unitId for reference if needed
        'schoolId': widget.schoolId, // Store schoolId
        'parish': widget.parish,
        'sundaySchool': widget.sundaySchool,
        'animatorId': animatorId,
        'animatorName': _animatorName,
        'year': currentYear,
        'marks': _marks,
        'pdfUrl': _pdfUrl,
        'locked': true,
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isLocked = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marks submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting marks: $e')));
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
            const SnackBar(
              content: Text('PDF Uploaded Successfully!'),
              backgroundColor: Colors.green,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mark Entry',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              '${widget.parish} - ${widget.sundaySchool}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: _isLoading
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
                    style: TextStyle(color: Colors.blue.shade900, fontSize: 16),
                  ),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20.0),
                  children: [
                    if (_isLocked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.shade300,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock,
                              color: Colors.amber.shade700,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'These marks have been submitted and are locked.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Questions Section
                    ..._questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      final questionText = data['text'] ?? 'Question';
                      final maxMark = data['maxMark'] ?? 10;
                      final qId = doc.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Colors.blue.shade100,
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question Header
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade900,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        questionText,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Mark Input
                                TextFormField(
                                  initialValue: _marks[qId]?.toString(),
                                  decoration: InputDecoration(
                                    labelText: 'Mark (Max: $maxMark)',
                                    labelStyle: TextStyle(
                                      color: Colors.blue.shade700,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.blue.shade900,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: Icon(
                                      Icons.edit_outlined,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  readOnly: _isLocked,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a mark';
                                    }
                                    final mark = int.tryParse(value);
                                    if (mark == null) {
                                      return 'Invalid number';
                                    }
                                    if (mark < 0 || mark > maxMark) {
                                      return 'Mark must be between 0 and $maxMark';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    final mark = int.tryParse(value);
                                    if (mark != null) {
                                      _marks[qId] = mark;
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // PDF Upload Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.upload_file_rounded,
                                  color: Colors.blue.shade900,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Answer Sheet PDF',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _pdfUrl != null
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _pdfUrl != null
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _pdfUrl != null
                                        ? Icons.check_circle_rounded
                                        : Icons.info_outline_rounded,
                                    color: _pdfUrl != null
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _pdfUrl != null
                                          ? 'PDF Uploaded Successfully'
                                          : 'No PDF Uploaded',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _pdfUrl != null
                                            ? Colors.green.shade900
                                            : Colors.grey.shade700,
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
                                child: ElevatedButton.icon(
                                  onPressed: _uploadPdf,
                                  icon: const Icon(Icons.cloud_upload_rounded),
                                  label: Text(
                                    _pdfUrl != null
                                        ? 'Change PDF'
                                        : 'Upload PDF',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    if (!_isLocked)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade700,
                              Colors.blue.shade900,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade900.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitMarks,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 24),
                                    SizedBox(width: 12),
                                    Text(
                                      'SUBMIT MARKS',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
