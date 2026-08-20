import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sundayschool_app/providers/user_data_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sundayschool_app/models/program_payment_details.dart';
import 'package:sundayschool_app/models/custom_field.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';
import 'package:http/http.dart' as http;
import 'package:sundayschool_app/utils/downloads_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sundayschool_app/utils/excel_registration_helper.dart';
import 'package:sundayschool_app/utils/image_optimizer.dart';

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
  bool _isCountOnlyProgram = false;
  bool _isProgramClosed = false;
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _parishUserId;
  String? _schoolName;
  String? _schoolDisplayName;

  bool _isLocked = false;

  // Payment integration state variables
  File? _paymentReceiptFile;
  String? _uploadedReceiptUrl;
  String? _existingReceiptUrl;
  ProgramPaymentDetails? _paymentDetails;

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
    if (_isCountOnly) {
      if (mounted) setState(() {});
      return;
    }
    if (_activeFields.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

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

  void _adjustCount(int delta) {
    HapticFeedback.selectionClick();
    final current = int.tryParse(_countController.text.trim()) ?? 0;
    final newCount = (current + delta).clamp(0, 99999);
    _countController.text = newCount == 0 ? '' : newCount.toString();
    _countController.selection = TextSelection.fromPosition(
      TextPosition(offset: _countController.text.length),
    );
    if (mounted) {
      setState(() {});
    }
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
          final isCountOnlyProg = data['isCountOnly'] == true;
          _isCountOnlyProgram = isCountOnlyProg;
          if (_isCountOnlyProgram) {
            _isCountOnly = true;
          }

          final isActive = data['isActive'] != false;
          final status = data['status'] as String?;
          final endDate = (data['endDate'] as Timestamp?)?.toDate();
          final startDate = (data['startDate'] as Timestamp?)?.toDate();
          final now = DateTime.now();
          if (!isActive ||
              status == 'closed' ||
              (endDate != null && now.isAfter(endDate)) ||
              (startDate != null && now.isBefore(startDate))) {
            _isProgramClosed = true;
          }

          final audience = data['targetAudience'] ?? 'student';
          _targetAudience = audience == 'teacher' ? 'teacher' : 'student';

          final fieldsKey = _targetAudience == 'teacher'
              ? 'teacherFields'
              : 'studentFields';
          final List<dynamic>? rawFields = data[fieldsKey];

          if (rawFields != null && rawFields.isNotEmpty) {
            _activeFields = rawFields
                .map(
                  (f) =>
                      CustomField.fromMap(Map<String, dynamic>.from(f as Map)),
                )
                .toList();
          } else {
            _activeFields = [
              CustomField(
                id: 'name',
                name: 'Name',
                type: 'text',
                isMandatory: true,
              ),
            ];
          }

          if (data['paymentDetails'] != null) {
            _paymentDetails = ProgramPaymentDetails.fromMap(
              Map<String, dynamic>.from(data['paymentDetails']),
            );
          }
        }
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

      // 3. If converting from count-only, fetch previous payment proof if present
      String? previousReceiptUrl;
      if (widget.convertToDetailedDocId != null) {
        final prevDoc = await FirebaseFirestore.instance
            .collection('program_registrations')
            .doc(widget.convertToDetailedDocId)
            .get();
        if (prevDoc.exists) {
          previousReceiptUrl = prevDoc.data()?['paymentScreenshotUrl'];
        }
      }

      if (!mounted) return;
      setState(() {
        _parishUserId = parishLink;
        _existingReceiptUrl = previousReceiptUrl;
        _uploadedReceiptUrl = previousReceiptUrl;
        _schoolName = userData.schoolName ?? userData.schoolDisplayName;
        _schoolDisplayName = userData.schoolDisplayName;
        _isLoading = false;

        // Initialize entries if a count is already set
        if (widget.convertToDetailedDocId != null &&
            widget.initialCount != null) {
          _updateStudentEntriesCount(widget.initialCount.toString());
        } else if (_countController.text.isNotEmpty) {
          _updateStudentEntriesCount(_countController.text);
        }
      });
    } catch (e) {
      debugPrint("Error loading program and context: $e");
      if (_activeFields.isEmpty) {
        _activeFields = [
          CustomField(
            id: 'name',
            name: 'Name',
            type: 'text',
            isMandatory: true,
          ),
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

  void _showModernSnackBar({
    required String title,
    required String message,
    required IconData icon,
    required Color primaryColor,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _downloadExcelTemplate() async {
    if (_activeFields.isEmpty) {
      _showModernSnackBar(
        title: 'No Fields Found',
        message: 'No active fields configured for this program.',
        icon: Icons.warning_amber_rounded,
        primaryColor: Colors.orange,
      );
      return;
    }

    final path = await ExcelRegistrationHelper.generateAndDownloadTemplate(
      programName: widget.programName,
      targetAudience: _targetAudience,
      activeFields: _activeFields,
    );

    if (path != null && mounted) {
      _showModernSnackBar(
        title: 'Template Downloaded!',
        message: 'Saved to your Downloads folder',
        icon: Icons.check_circle_rounded,
        primaryColor: const Color(0xFF10B981),
        actionLabel: 'OPEN',
        onAction: () => OpenFilex.open(
          path,
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      );
      // Auto open file with explicit MIME type
      OpenFilex.open(
        path,
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } else if (mounted) {
      _showModernSnackBar(
        title: 'Download Failed',
        message: 'Failed to generate Excel template file.',
        icon: Icons.error_rounded,
        primaryColor: Colors.redAccent,
      );
    }
  }

  Future<void> _uploadAndProcessExcel() async {
    if (_activeFields.isEmpty) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowCompression: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      // Filter extensions manually for MIUI file picker compatibility
      final String extension = (file.extension ?? '').toLowerCase();
      final String path = file.path ?? '';
      bool isValidExtension = extension == 'xlsx' ||
          extension == 'xls' ||
          extension == 'csv' ||
          path.endsWith('.xlsx') ||
          path.endsWith('.xls') ||
          path.endsWith('.csv');

      if (!isValidExtension) {
        if (mounted) {
          _showModernSnackBar(
            title: 'Invalid Format',
            message: 'Please select a valid Excel (.xlsx, .xls) or CSV (.csv) file.',
            icon: Icons.warning_amber_rounded,
            primaryColor: Colors.orange,
          );
        }
        return;
      }

      List<int>? fileBytes = file.bytes;
      if (fileBytes == null && path.isNotEmpty) {
        try {
          fileBytes = await File(path).readAsBytes();
        } catch (e) {
          debugPrint('Error reading file from path: $e');
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        if (mounted) {
          _showModernSnackBar(
            title: 'File Error',
            message: 'Could not read selected Excel/CSV file.',
            icon: Icons.error_rounded,
            primaryColor: Colors.redAccent,
          );
        }
        return;
      }

      final parseResult = ExcelRegistrationHelper.parseUploadedExcel(
        bytes: fileBytes,
        activeFields: _activeFields,
      );

      if (!mounted) return;

      if (parseResult.records.isEmpty) {
        final errorMsg = parseResult.warnings.isNotEmpty
            ? parseResult.warnings.join('\n')
            : 'No valid records found in uploaded file.';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Excel Upload Error', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
            content: Text(errorMsg, style: GoogleFonts.poppins(fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      _showExcelSummaryModal(parseResult);
    } catch (e) {
      debugPrint('Error uploading excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading excel file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showExcelSummaryModal(ExcelParseResult parseResult) {
    final int count = parseResult.records.length;

    double fullAmount = 0;
    double advanceDue = 0;
    bool hasPayment = _paymentDetails != null && _paymentDetails!.isRequired;

    if (hasPayment) {
      fullAmount = count * _paymentDetails!.registrationFee;
      final isFixed = _paymentDetails!.advanceType == 'fixed';
      advanceDue = isFixed
          ? (count * _paymentDetails!.advanceValue)
          : (fullAmount * (_paymentDetails!.advanceValue / 100));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.table_chart_rounded, color: Colors.green.shade700, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excel Sheet Processed',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                        Text(
                          'Review upload summary before applying',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Summary Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withAlpha(120),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Valid Entries:', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade800)),
                        Text('$count ${_targetAudience}s', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      ],
                    ),
                    if (hasPayment) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Registration Fee:', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
                          Text('₹${fullAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Advance to Pay:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                          Text('₹${advanceDue.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              if (parseResult.warnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade800),
                          const SizedBox(width: 6),
                          Text('Warnings / Skipped Rows', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...parseResult.warnings.take(3).map((w) => Text('• $w', style: GoogleFonts.poppins(fontSize: 11, color: Colors.amber.shade900))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyExcelDataToForm(parseResult.records);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text('Populate Registration Form ($count)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyExcelDataToForm(List<Map<String, String>> records) {
    setState(() {
      _isCountOnly = false;
      _countController.text = records.length.toString();
    });

    // Populate input controllers
    for (int i = 0; i < records.length && i < _studentEntries.length; i++) {
      final recordMap = records[i];
      final entryControllers = _studentEntries[i];

      for (var field in _activeFields) {
        if (recordMap.containsKey(field.id) && entryControllers.containsKey(field.id)) {
          String val = (recordMap[field.id] ?? '').trim();

          final isSelect = field.type == 'select' ||
              field.id.toLowerCase() == 'class' ||
              field.id.toLowerCase() == 'studentclass' ||
              field.name.toLowerCase() == 'class';

          if (isSelect && val.isNotEmpty) {
            final List<String> dropdownOptions =
                (field.options != null && field.options!.isNotEmpty)
                    ? field.options!
                    : List.generate(12, (index) => (index + 1).toString());

            // 1. Direct match
            if (!dropdownOptions.contains(val)) {
              // 2. Normalize "Class 5" -> "5" or "5" -> "Class 5"
              final cleanedDigits = val.replaceAll(RegExp(r'[^\d]'), '');
              String? matchedOption;

              for (var opt in dropdownOptions) {
                final optDigits = opt.replaceAll(RegExp(r'[^\d]'), '');
                if (opt == val ||
                    opt.toLowerCase() == val.toLowerCase() ||
                    (cleanedDigits.isNotEmpty && optDigits == cleanedDigits)) {
                  matchedOption = opt;
                  break;
                }
              }

              if (matchedOption != null) {
                val = matchedOption;
              }
            }
          }

          entryControllers[field.id]!.text = val;
        }
      }
    }

    _showModernSnackBar(
      title: 'Excel Data Loaded!',
      message: 'Successfully populated ${records.length} entries into form.',
      icon: Icons.table_rows_rounded,
      primaryColor: const Color(0xFF10B981),
    );
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
      if (_paymentDetails != null && _paymentDetails!.isRequired) {
        if (_paymentReceiptFile != null) {
          final uploadUrl = await _uploadReceipt(_paymentReceiptFile!);
          if (uploadUrl == null) {
            throw Exception(
              'Failed to upload payment proof. Please try again.',
            );
          }
          _uploadedReceiptUrl = uploadUrl;
        }
      }

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
          'studentName': 'Count-Only ($count ${isTeacher ? 'Teachers' : 'Attendees'})',
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'pending_parish',
          if (_schoolName != null) 'schoolName': _schoolName,
          'type': _targetAudience,
          if (_paymentDetails?.isRequired == true)
            'paymentScreenshotUrl': _uploadedReceiptUrl,
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

            if (fieldIdLower == 'name' ||
                (fallbackName == null && fieldNameLower.contains('name'))) {
              fallbackName = val;
            }
            if (fieldIdLower == 'phone' ||
                field.type == 'phone' ||
                (fallbackPhone == null &&
                    (fieldNameLower.contains('phone') ||
                        fieldNameLower.contains('mobile') ||
                        fieldNameLower.contains('contact')))) {
              fallbackPhone = val;
            }
            if (fieldIdLower == 'address' ||
                (fallbackAddress == null &&
                    fieldNameLower.contains('address'))) {
              fallbackAddress = val;
            }
            if (fieldIdLower == 'class' ||
                fieldIdLower == 'studentclass' ||
                (fallbackClass == null && fieldNameLower.contains('class'))) {
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
            if (fallbackAddress != null && fallbackAddress.isNotEmpty)
              'studentAddress': fallbackAddress,
            if (fallbackClass != null && fallbackClass.isNotEmpty)
              'studentClass': fallbackClass,
            if (_paymentDetails?.isRequired == true)
              'paymentScreenshotUrl': _uploadedReceiptUrl,
          });
        }
      }

      if (widget.convertToDetailedDocId != null && !_isCountOnly) {
        final convertDocRef = collection.doc(widget.convertToDetailedDocId);
        batch.delete(convertDocRef);
      }

      await batch.commit();

      if (mounted) {
        final totalRegistrants = _isCountOnly
            ? (int.tryParse(_countController.text) ?? 0)
            : _studentEntries.length;

        await _showStatusDialog(
          context: context,
          isSuccess: true,
          title: "Registration Successful!",
          message: _isCountOnly
              ? 'Successfully registered ${_countController.text.trim()} ${isTeacher ? 'teachers' : 'students'}!'
              : 'Successfully registered ${_studentEntries.length} ${isTeacher ? 'teachers' : 'students'}!',
        );

        if (mounted) {
          final isCountConversion = widget.convertToDetailedDocId != null && !_isCountOnly;
          final initialCount = widget.initialCount ?? 0;
          final isSameOrReducedCount = isCountConversion && totalRegistrants <= initialCount;
          final hasInheritedReceipt = _existingReceiptUrl != null && _existingReceiptUrl!.isNotEmpty;

          if (_paymentDetails != null &&
              _paymentDetails!.isRequired &&
              _paymentReceiptFile == null &&
              !(isSameOrReducedCount && hasInheritedReceipt)) {
            _showPaymentDetailsSheet(
              context,
              totalRegistrants,
              isPostSubmit: true,
            );
          } else {
            Navigator.pop(context);
          }
        }
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

  Future<String?> _uploadReceipt(File file) async {
    try {
      final optimizedFile =
          await ImageOptimizer.compressBelowLimit(file, targetSizeKB: 250) ??
          file;

      final storageRef = FirebaseStorage.instance.ref().child(
        'programs/receipts/${widget.programId}/${FirebaseAuth.instance.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final uploadTask = await storageRef.putFile(
        optimizedFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Failed to upload payment proof: $e");
      return null;
    }
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
    } else if (field.type == 'phone' ||
        idLower == 'phone' ||
        nameLower.contains('phone') ||
        nameLower.contains('mobile') ||
        nameLower.contains('contact')) {
      return Icons.phone_android_rounded;
    } else if (idLower == 'class' ||
        idLower == 'studentclass' ||
        nameLower.contains('class') ||
        nameLower.contains('grade')) {
      return Icons.school_rounded;
    } else if (idLower == 'address' ||
        nameLower.contains('address') ||
        nameLower.contains('location') ||
        nameLower.contains('residence')) {
      return Icons.home_work_outlined;
    } else if (field.type == 'number' ||
        nameLower.contains('age') ||
        nameLower.contains('number')) {
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
                    const SizedBox(height: 16),

                    if (_isProgramClosed) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_clock_rounded,
                                color: Colors.red.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Registration Closed',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'The registration period for this program has ended or is inactive.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

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

                    // --- EXCEL TEMPLATE & UPLOAD ACTION CARD ---
                    if (!_isCountOnlyProgram && !_isCountOnly)
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.teal.shade50,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withAlpha(20),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade700,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.table_view_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Bulk Excel Registration',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Optional',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Tap to expand Excel bulk options',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            children: [
                              Text(
                                'Download template, fill details, and upload to auto-fill entries.',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isNarrow = constraints.maxWidth < 330;
                                  if (isNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _downloadExcelTemplate,
                                          icon: const Icon(Icons.download_rounded, size: 18),
                                          label: Text(
                                            'Download Template',
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.teal.shade900,
                                            side: BorderSide(color: Colors.teal.shade600),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: _uploadAndProcessExcel,
                                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                                          label: Text(
                                            'Upload Excel Sheet',
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal.shade700,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _downloadExcelTemplate,
                                          icon: const Icon(Icons.download_rounded, size: 18),
                                          label: Text(
                                            'Download Template',
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.teal.shade900,
                                            side: BorderSide(color: Colors.teal.shade600),
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _uploadAndProcessExcel,
                                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                                          label: Text(
                                            'Upload Excel Sheet',
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal.shade700,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    // --- SEGMENTED CONTROL TOGGLE ---
                    if (!_isCountOnlyProgram)
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
                    _buildPaymentSection(),

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed:
                          (_isSubmitting ||
                                  _parishUserId == null ||
                                  _isLoading ||
                                  _isLocked ||
                                  _isProgramClosed)
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
                          gradient: (_isLocked || _isProgramClosed)
                              ? LinearGradient(
                                  colors: [
                                    Colors.grey.shade600,
                                    Colors.grey.shade700,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
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
                                  _isProgramClosed
                                      ? 'Registration Closed'
                                      : _isLocked
                                          ? 'Registration Locked'
                                          : _isCountOnly
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
    final currentVal = int.tryParse(_countController.text.trim()) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Information Banner for Count-Only Programs / Modes
        if (_isCountOnlyProgram || _isCountOnly) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.indigo.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue.shade800,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Headcount Submission Only',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'This requires headcount submission only. Individual ${isTeacher ? 'teacher' : 'student'} details are not required.',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: Colors.blue.shade800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Headcount Input Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.indigo.shade50),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withAlpha(18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.indigo.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 38,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Total ${isTeacher ? 'Teachers' : 'Students'}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the total number of ${isTeacher ? 'teachers' : 'students'} participating',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Stepper Row (- / Input / +)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: currentVal > 0 ? () => _adjustCount(-1) : null,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.remove_rounded,
                          color: currentVal > 0
                              ? Colors.indigo.shade900
                              : Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade400,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.indigo.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.indigo.shade100),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
                        ),
                        fillColor: Colors.grey.shade50,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 8,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = int.tryParse(val.trim());
                        if (num == null || num <= 0) return '> 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Material(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _adjustCount(1),
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.indigo.shade900,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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

                  final isSelect = field.type == 'select' ||
                      field.id.toLowerCase() == 'class' ||
                      field.id.toLowerCase() == 'studentclass' ||
                      field.name.toLowerCase() == 'class';
                  final isPhone =
                      field.type == 'phone' ||
                      field.id.toLowerCase() == 'phone' ||
                      field.name.toLowerCase().contains('phone');
                  final isNumber =
                      field.type == 'number' ||
                      field.name.toLowerCase().contains('age') ||
                      field.name.toLowerCase().contains('number');
                  final isAddress =
                      field.id.toLowerCase() == 'address' ||
                      field.name.toLowerCase().contains('address');

                  String label = field.name;
                  if (field.name.toLowerCase() == 'name') {
                    label = '${isTeacher ? 'Teacher' : 'Student'} Name';
                  }

                  if (isSelect) {
                    final List<String> dropdownOptions =
                        (field.options != null && field.options!.isNotEmpty)
                            ? field.options!
                            : List.generate(12, (index) => (index + 1).toString());

                    String? currentValue;
                    final textVal = controller.text.trim();
                    if (textVal.isNotEmpty) {
                      if (dropdownOptions.contains(textVal)) {
                        currentValue = textVal;
                      } else {
                        final digits = textVal.replaceAll(RegExp(r'[^\d]'), '');
                        for (var opt in dropdownOptions) {
                          final optDigits = opt.replaceAll(RegExp(r'[^\d]'), '');
                          if (opt.toLowerCase() == textVal.toLowerCase() ||
                              (digits.isNotEmpty && optDigits == digits)) {
                            currentValue = opt;
                            break;
                          }
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        value: currentValue,
                        decoration: InputDecoration(
                          labelText: label,
                          prefixIcon: Icon(_getFieldIcon(field)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          fillColor: Colors.grey.shade50,
                          filled: true,
                        ),
                        items: dropdownOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt,
                            child: Text(opt.startsWith('Class ') ? opt : 'Class $opt'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            controller.text = val;
                          }
                        },
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

  Widget _buildPaymentSection() {
    if (_paymentDetails == null || !_paymentDetails!.isRequired) {
      return const SizedBox.shrink();
    }

    final totalRegistrants = _isCountOnly
        ? (int.tryParse(_countController.text) ?? 0)
        : _studentEntries.length;

    final fullAmount = totalRegistrants * _paymentDetails!.registrationFee;
    final isFixed = _paymentDetails!.advanceType == 'fixed';
    final amountDue = isFixed
        ? (totalRegistrants * _paymentDetails!.advanceValue)
        : (fullAmount * (_paymentDetails!.advanceValue / 100));
    final hasAdvance =
        _paymentDetails!.advanceValue <
        (isFixed ? _paymentDetails!.registrationFee : 100);

    return FormField<File>(
      validator: (value) {
        // Payment proof is optional now since they can pay later
        return null;
      },
      builder: (formFieldState) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: formFieldState.hasError
                  ? Colors.red.shade300
                  : Colors.indigo.shade50,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This registration requires payment. You can upload the payment proof screenshot now, or submit the form and pay later.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Registration Fee',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  Text(
                    '₹${_paymentDetails!.registrationFee.toStringAsFixed(0)} / person',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasAdvance) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Fee ($totalRegistrants persons)',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    Text(
                      '₹${fullAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blueGrey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFixed
                                  ? 'ADVANCE REQUIRED (FIXED)'
                                  : 'ADVANCE REQUIRED (${_paymentDetails!.advanceValue.toStringAsFixed(0)}%)',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.orange.shade900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isFixed
                                  ? '₹${_paymentDetails!.advanceValue.toStringAsFixed(0)} / person'
                                  : 'Pay ${_paymentDetails!.advanceValue.toStringAsFixed(0)}% of total',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${amountDue.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL AMOUNT DUE (100%)',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.green.shade900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Full fee payment required',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${amountDue.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    _showPaymentDetailsSheet(context, totalRegistrants),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade900,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.payment_rounded),
                label: Text(
                  'Make Payment',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Upload Payment Screenshot',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              if (_paymentReceiptFile != null) ...[
                Stack(
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: FileImage(_paymentReceiptFile!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.red,
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _paymentReceiptFile = null;
                            });
                            formFieldState.didChange(null);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_existingReceiptUrl != null &&
                  _existingReceiptUrl!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Proof Already Attached',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                                Text(
                                  'Saved from your initial count registration',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrl: _existingReceiptUrl!,
                                    heroTag: 'existing_receipt_preview',
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'View',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _pickReceiptImage(
                          ImageSource.gallery,
                          formFieldState,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: Colors.green.shade300),
                          foregroundColor: Colors.green.shade900,
                        ),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text(
                          'Upload New Screenshot (Optional)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickReceiptImage(
                          ImageSource.gallery,
                          formFieldState,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text('Gallery', style: GoogleFonts.poppins()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickReceiptImage(
                          ImageSource.camera,
                          formFieldState,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text('Camera', style: GoogleFonts.poppins()),
                      ),
                    ),
                  ],
                ),
              ],
              if (formFieldState.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  formFieldState.errorText ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickReceiptImage(
    ImageSource source,
    FormFieldState<File> state,
  ) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _paymentReceiptFile = File(pickedFile.path);
        });
        state.didChange(_paymentReceiptFile);
      }
    } catch (e) {
      debugPrint("Error picking receipt image: $e");
    }
  }

  void _showModernDownloadDialog(
    BuildContext context, {
    required String status,
    String? fileName,
    String? filePath,
    String? errorMessage,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: status != 'loading',
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'loading') ...[
                  const SizedBox(height: 8),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Saving QR Code...',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Downloading payment details',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (status == 'success') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green.shade700,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Download Complete!',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The QR code image is ready to view.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blueGrey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          fileName ?? '',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.blueGrey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saved to Downloads folder',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.blueGrey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (filePath != null) {
                        OpenFilex.open(filePath);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Open Image',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else if (status == 'error') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red.shade700,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Download Failed',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'An error occurred during download.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blueGrey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      if (onRetry != null) onRetry();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Retry',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        color: Colors.blueGrey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadQrCode(
    BuildContext context,
    String url,
    String programName,
  ) async {
    // Show modern loading state
    _showModernDownloadDialog(context, status: 'loading');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final cleanProgramName = programName.replaceAll(
          RegExp(r'[^\w\s\-]'),
          '_',
        );
        final fileName =
            'QR_${cleanProgramName}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        if (!context.mounted) return;
        final savedPath = await DownloadsHelper.saveToDownloads(
          bytes,
          fileName,
          context: context,
        );
        if (savedPath != null) {
          if (context.mounted) {
            Navigator.pop(context); // Dismiss loading dialog
            _showModernDownloadDialog(
              context,
              status: 'success',
              fileName: fileName,
              filePath: savedPath,
            );
          }
        } else {
          throw Exception('Failed to save file to downloads directory');
        }
      } else {
        throw Exception('Failed to fetch QR image from server');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        _showModernDownloadDialog(
          context,
          status: 'error',
          errorMessage: e.toString(),
          onRetry: () => _downloadQrCode(context, url, programName),
        );
      }
    }
  }

  void _showPaymentDetailsSheet(
    BuildContext context,
    int totalRegistrants, {
    bool isPostSubmit = false,
  }) {
    final fullAmount = totalRegistrants * _paymentDetails!.registrationFee;
    final isFixed = _paymentDetails!.advanceType == 'fixed';
    final amountDue = isFixed
        ? (totalRegistrants * _paymentDetails!.advanceValue)
        : (fullAmount * (_paymentDetails!.advanceValue / 100));
    final hasAdvance = amountDue < fullAmount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Payment Details',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.blue.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isPostSubmit) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Registration submitted! Please make the payment now, or close and pay later.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                _buildDetailRow('Account Name', _paymentDetails!.accountName),
                _buildCopyableDetailRow(
                  'Account Number',
                  _paymentDetails!.accountNumber,
                ),
                _buildCopyableDetailRow('IFSC Code', _paymentDetails!.ifscCode),
                _buildDetailRow('Bank Name', _paymentDetails!.bankName),
                _buildDetailRow(
                  'Registration Fee',
                  '₹${_paymentDetails!.registrationFee.toStringAsFixed(0)} / person',
                ),
                const Divider(height: 24),
                if (hasAdvance) ...[
                  _buildDetailRow(
                    'Total Fee ($totalRegistrants persons)',
                    '₹${fullAmount.toStringAsFixed(0)}',
                  ),
                  _buildDetailRow(
                    isFixed
                        ? 'Advance Required (Fixed)'
                        : 'Advance Percentage Required',
                    isFixed
                        ? '₹${_paymentDetails!.advanceValue.toStringAsFixed(0)} / person'
                        : '${_paymentDetails!.advanceValue.toStringAsFixed(0)}%',
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Advance Amount Due',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                      Text(
                        '₹${amountDue.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount Due (100%)',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                      Text(
                        '₹${amountDue.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                if (_paymentDetails!.qrCodeUrl.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Scan QR Code to Pay',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.blue,
                        ),
                        tooltip: 'Download QR Code',
                        onPressed: () => _downloadQrCode(
                          context,
                          _paymentDetails!.qrCodeUrl,
                          widget.programName,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageViewer(
                              imageUrl: _paymentDetails!.qrCodeUrl,
                              heroTag: 'qr_code_hero_form',
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'qr_code_hero_form',
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: _paymentDetails!.qrCodeUrl,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey.shade200,
                                highlightColor: Colors.grey.shade100,
                                child: Container(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.qr_code_2_rounded,
                                size: 100,
                                color: Colors.grey,
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (isPostSubmit) {
                      Navigator.pop(context); // Close the form screen
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isPostSubmit ? 'Pay Later' : 'Close',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.blueGrey.shade600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.blueGrey.shade600,
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: Colors.blue,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied to clipboard'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
