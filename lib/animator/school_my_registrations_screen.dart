import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sundayschool_app/animator/student_registration_form.dart';
import 'package:sundayschool_app/models/custom_field.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sundayschool_app/models/program_payment_details.dart';
import 'package:sundayschool_app/widgets/full_screen_image_viewer.dart';
import 'package:http/http.dart' as http;
import 'package:sundayschool_app/utils/downloads_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:sundayschool_app/utils/image_optimizer.dart';

class SchoolMyRegistrationsScreen extends StatelessWidget {
  const SchoolMyRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'My Registrations',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade700],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'View My Registration History',
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UserRegistrationHistoryScreen(userId: user.uid),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .where('schoolUserId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No registrations found",
                style: GoogleFonts.poppins(),
              ),
            );
          }

          // Group by Program
          final Map<String, int> programCounts = {};
          final Map<String, String> programIds = {};
          // Check lock status per program (if any entry is locked, program is locked)
          final Map<String, bool> programLocked = {};
          final Map<String, String> programTypes = {};

          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final pName = data['programName'] as String? ?? 'Unknown';
            final pId = data['programId'] as String? ?? '';
            final status = data['status'] as String? ?? 'pending';
            final type = data['type']?.toString() ?? 'student';

            final isCountOnly = data['isCountOnly'] == true;
            final studentCount = isCountOnly
                ? (data['studentCount'] as int? ?? 1)
                : 1;

            programCounts[pName] = (programCounts[pName] ?? 0) + studentCount;
            programIds[pName] = pId;
            programTypes[pName] = type;
            if (status == 'locked') {
              programLocked[pName] = true;
            }
          }

          final programs = programCounts.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final pName = programs[index];
              final count = programCounts[pName]!;
              final isLocked = programLocked[pName] ?? false;
              final type = programTypes[pName] ?? 'student';
              final bool isTeacher = type == 'teacher';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SchoolProgramDetailScreen(
                            programName: pName,
                            programId: programIds[pName] ?? '',
                            isLocked: isLocked,
                          ),
                        ),
                      );
                    },
                    title: Text(
                      pName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$count ${isTeacher ? 'Teacher' : 'Student'}${count == 1 ? '' : 's'} Registered',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isLocked
                                ? Colors.grey.shade100
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isLocked ? "Locked" : "Open",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isLocked
                                  ? Colors.grey.shade600
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
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

class SchoolProgramDetailScreen extends StatefulWidget {
  final String programName;
  final String programId;
  final bool isLocked;

  const SchoolProgramDetailScreen({
    super.key,
    required this.programName,
    required this.programId,
    required this.isLocked,
  });

  @override
  State<SchoolProgramDetailScreen> createState() =>
      _SchoolProgramDetailScreenState();
}

class _SchoolProgramDetailScreenState extends State<SchoolProgramDetailScreen> {
  bool _isSaving = false;
  List<CustomField> _studentFields = [];
  List<CustomField> _teacherFields = [];
  bool _isLoadingFields = true;
  ProgramPaymentDetails? _paymentDetails;
  bool _isUploadingReceipt = false;

  @override
  void initState() {
    super.initState();
    _loadProgramFields();
  }

  Future<void> _loadProgramFields() async {
    try {
      final programDoc = await FirebaseFirestore.instance
          .collection('programs')
          .doc(widget.programId)
          .get();

      if (programDoc.exists) {
        final data = programDoc.data();
        if (data != null) {
          final List<dynamic>? rawStudentFields = data['studentFields'];
          if (rawStudentFields != null) {
            _studentFields = rawStudentFields
                .map(
                  (f) =>
                      CustomField.fromMap(Map<String, dynamic>.from(f as Map)),
                )
                .toList();
          }
          final List<dynamic>? rawTeacherFields = data['teacherFields'];
          if (rawTeacherFields != null) {
            _teacherFields = rawTeacherFields
                .map(
                  (f) =>
                      CustomField.fromMap(Map<String, dynamic>.from(f as Map)),
                )
                .toList();
          }
          if (data['paymentDetails'] != null) {
            _paymentDetails = ProgramPaymentDetails.fromMap(
              Map<String, dynamic>.from(data['paymentDetails']),
            );
          }
        }
      }

      // Fallbacks if not set
      if (_studentFields.isEmpty) {
        _studentFields = [
          CustomField(
            id: 'name',
            name: 'Name',
            type: 'text',
            isMandatory: true,
          ),
          CustomField(
            id: 'phone',
            name: 'Phone',
            type: 'phone',
            isMandatory: true,
          ),
          CustomField(
            id: 'studentClass',
            name: 'Class',
            type: 'select',
            isMandatory: false,
            options: List.generate(12, (index) => (index + 1).toString()),
          ),
          CustomField(
            id: 'address',
            name: 'Address',
            type: 'text',
            isMandatory: false,
          ),
        ];
      }
      if (_teacherFields.isEmpty) {
        _teacherFields = [
          CustomField(
            id: 'name',
            name: 'Name',
            type: 'text',
            isMandatory: true,
          ),
          CustomField(
            id: 'phone',
            name: 'Phone',
            type: 'phone',
            isMandatory: true,
          ),
          CustomField(
            id: 'studentClass',
            name: 'Class',
            type: 'select',
            isMandatory: false,
            options: List.generate(12, (index) => (index + 1).toString()),
          ),
          CustomField(
            id: 'address',
            name: 'Address',
            type: 'text',
            isMandatory: false,
          ),
        ];
      }
    } catch (e) {
      debugPrint("Error loading program fields: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFields = false;
        });
      }
    }
  }

  Future<String?> _uploadReceiptToStorage(File file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Compress/Optimize the image first to speed up upload
      final optimizedFile =
          await ImageOptimizer.compressBelowLimit(file, targetSizeKB: 250) ??
          file;

      final storageRef = FirebaseStorage.instance.ref().child(
        'programs/receipts/${widget.programId}/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
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

  void _showUploadProgressDialog(
    BuildContext context,
    File file,
    List<QueryDocumentSnapshot> docs,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        double progress = 0.0;
        String statusText = "Optimizing image...";
        bool isDone = false;
        bool isError = false;
        String errorMessage = "";
        bool started = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!started) {
              started = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  // Step 1: Compress image
                  final optimizedFile =
                      await ImageOptimizer.compressBelowLimit(
                        file,
                        targetSizeKB: 250,
                      ) ??
                      file;

                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    statusText = "Uploading payment proof...";
                    progress = 0.01;
                  });

                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) throw Exception("User not authenticated");

                  final storageRef = FirebaseStorage.instance.ref().child(
                    'programs/receipts/${widget.programId}/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  );

                  final uploadTask = storageRef.putFile(
                    optimizedFile,
                    SettableMetadata(contentType: 'image/jpeg'),
                  );

                  uploadTask.snapshotEvents.listen(
                    (TaskSnapshot snapshot) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          progress =
                              snapshot.bytesTransferred / snapshot.totalBytes;
                          if (progress >= 1.0) {
                            statusText = "Saving to database...";
                          }
                        });
                      }
                    },
                    onError: (e) {
                      throw e;
                    },
                  );

                  final TaskSnapshot snapshot = await uploadTask;
                  final downloadUrl = await snapshot.ref.getDownloadURL();

                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    statusText = "Finalizing...";
                  });

                  // Step 2: Update Firestore batch
                  final batch = FirebaseFirestore.instance.batch();
                  for (final doc in docs) {
                    batch.update(doc.reference, {
                      'paymentScreenshotUrl': downloadUrl,
                    });
                  }
                  await batch.commit();

                  if (dialogContext.mounted) {
                    setDialogState(() {
                      isDone = true;
                      statusText = "Upload Successful!";
                    });
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    setDialogState(() {
                      isError = true;
                      errorMessage = e.toString();
                    });
                  }
                }
              });
            }

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
                    if (isDone) ...[
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
                        'Uploaded Successfully!',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your payment screenshot has been uploaded and submitted.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext); // Close dialog
                          Navigator.pop(context); // Close bottom sheet
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
                          'Done',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ] else if (isError) ...[
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
                        'Upload Failed',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
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
                          'Close',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        width: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 90,
                              width: 90,
                              child: CircularProgressIndicator(
                                value: progress > 0 ? progress : null,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.blue.shade900,
                                ),
                                strokeWidth: 6,
                                backgroundColor: Colors.grey.shade100,
                              ),
                            ),
                            if (progress > 0)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        statusText,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please do not close the app',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blueGrey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  void _showUploadPaymentSheet(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    int totalRegistrants,
  ) {
    final fullAmount = totalRegistrants * _paymentDetails!.registrationFee;
    final isFixed = _paymentDetails!.advanceType == 'fixed';
    final amountDue = isFixed
        ? (totalRegistrants * _paymentDetails!.advanceValue)
        : (fullAmount * (_paymentDetails!.advanceValue / 100));
    final hasAdvance = amountDue < fullAmount;

    File? localReceiptFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(
                  source: source,
                  imageQuality: 85,
                );
                if (pickedFile != null) {
                  setSheetState(() {
                    localReceiptFile = File(pickedFile.path);
                  });
                }
              } catch (e) {
                debugPrint("Error picking receipt image: $e");
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
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
                      'Complete Payment',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.blue.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      'Account Name',
                      _paymentDetails!.accountName,
                    ),
                    _buildCopyableDetailRow(
                      'Account Number',
                      _paymentDetails!.accountNumber,
                    ),
                    _buildCopyableDetailRow(
                      'IFSC Code',
                      _paymentDetails!.ifscCode,
                    ),
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
                                  heroTag: 'qr_code_hero_details',
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'qr_code_hero_details',
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: _paymentDetails!.qrCodeUrl,
                                  placeholder: (context, url) =>
                                      Shimmer.fromColors(
                                        baseColor: Colors.grey.shade200,
                                        highlightColor: Colors.grey.shade100,
                                        child: Container(color: Colors.white),
                                      ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
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
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'Upload Payment Screenshot',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (localReceiptFile != null) ...[
                      Stack(
                        children: [
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              image: DecorationImage(
                                image: FileImage(localReceiptFile!),
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
                                  setSheetState(() {
                                    localReceiptFile = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickImage(ImageSource.gallery),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(
                                'Gallery',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickImage(ImageSource.camera),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: Text(
                                'Camera',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed:
                          (localReceiptFile == null || _isUploadingReceipt)
                          ? null
                          : () {
                              _showUploadProgressDialog(
                                context,
                                localReceiptFile!,
                                docs,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isUploadingReceipt
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit Payment Proof',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(
                        'Pay Later',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentStatusCard(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
    int totalRegistrants,
    bool hasPaid,
    String? screenshotUrl, {
    int paidRegistrants = 0,
  }) {
    final fullAmount = totalRegistrants * _paymentDetails!.registrationFee;
    final isFixed = _paymentDetails!.advanceType == 'fixed';
    final amountDue = isFixed
        ? (totalRegistrants * _paymentDetails!.advanceValue)
        : (fullAmount * (_paymentDetails!.advanceValue / 100));
    final hasAdvance = amountDue < fullAmount;

    final isPaid = hasPaid;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? Colors.green.shade200 : Colors.amber.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isPaid
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: isPaid ? Colors.green.shade700 : Colors.amber.shade800,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPaid ? 'Payment Received' : 'Payment Proof Required',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isPaid
                        ? Colors.green.shade900
                        : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPaid ? 'Amount Paid' : 'Amount Due',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isPaid ? Colors.green.shade800 : Colors.amber.shade800,
                ),
              ),
              Text(
                hasAdvance
                    ? '$totalRegistrants × ₹${(isFixed ? _paymentDetails!.advanceValue : (_paymentDetails!.registrationFee * _paymentDetails!.advanceValue / 100)).toStringAsFixed(0)} = ₹${(hasAdvance ? amountDue : fullAmount).toStringAsFixed(0)}'
                    : '$totalRegistrants × ₹${_paymentDetails!.registrationFee.toStringAsFixed(0)} = ₹${fullAmount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isPaid ? Colors.green.shade900 : Colors.amber.shade900,
                ),
              ),
            ],
          ),
          if (hasAdvance) ...[
            const SizedBox(height: 4),
            Text(
              isPaid
                  ? 'Paid ${isFixed ? 'fixed advance' : '${_paymentDetails!.advanceValue.toStringAsFixed(0)}% advance'}'
                  : '${isFixed ? 'Fixed advance (₹${_paymentDetails!.advanceValue.toStringAsFixed(0)}/person)' : '${_paymentDetails!.advanceValue.toStringAsFixed(0)}% advance'} required',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isPaid ? Colors.green.shade700 : Colors.amber.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (!isPaid && paidRegistrants > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Already Paid',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  Text(
                    hasAdvance
                        ? '$paidRegistrants × ₹${(isFixed ? _paymentDetails!.advanceValue : (_paymentDetails!.registrationFee * _paymentDetails!.advanceValue / 100)).toStringAsFixed(0)} = ₹${(isFixed ? (paidRegistrants * _paymentDetails!.advanceValue) : (paidRegistrants * _paymentDetails!.registrationFee * _paymentDetails!.advanceValue / 100)).toStringAsFixed(0)}'
                        : '$paidRegistrants × ₹${_paymentDetails!.registrationFee.toStringAsFixed(0)} = ₹${(paidRegistrants * _paymentDetails!.registrationFee).toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isPaid) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  _showUploadPaymentSheet(context, docs, totalRegistrants),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.payment_rounded),
              label: Text(
                'Pay Now',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
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

  void _showViewDetailsDialog(Map<String, dynamic> data) {
    final String type = data['type']?.toString() ?? 'student';
    final bool isTeacher = type == 'teacher';
    final fields = isTeacher ? _teacherFields : _studentFields;
    final customValues =
        data['customFieldValues'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isTeacher ? 'Teacher Details' : 'Student Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...fields.map((field) {
                String value = customValues[field.id]?.toString() ?? '';
                if (value.isEmpty) {
                  if (field.id == 'name') {
                    value = data['studentName']?.toString() ?? '';
                  } else if (field.type == 'phone' || field.id == 'phone') {
                    value = data['studentPhone']?.toString() ?? '';
                  } else if (field.id == 'address' ||
                      field.id == 'studentAddress') {
                    value = data['studentAddress']?.toString() ?? '';
                  } else if (field.id == 'studentClass') {
                    value = data['studentClass']?.toString() ?? '';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value.isNotEmpty ? value : 'N/A',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const Divider(),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          'Are you sure you want to delete this registration? This action cannot be undone.',
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
      try {
        await FirebaseFirestore.instance
            .collection('program_registrations')
            .doc(docId)
            .delete();
        if (mounted) {
          await _showStatusDialog(
            context: context,
            isSuccess: true,
            title: "Deleted!",
            message: "Registration has been deleted successfully.",
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
        }
      }
    }
  }

  void _showActionSheet(String docId, Map<String, dynamic> data) {
    if (widget.isLocked) return;
    final bool isCountOnly = data['isCountOnly'] == true;
    final String type = data['type']?.toString() ?? 'student';
    final bool isTeacher = type == 'teacher';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Registration Actions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_rounded, color: Colors.blue.shade700),
              ),
              title: Text(
                'Edit Details',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showEditBottomSheet(docId, data);
              },
            ),
            if (isCountOnly) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    color: Colors.orange.shade700,
                  ),
                ),
                title: Text(
                  isTeacher ? 'Enter Teacher Details' : 'Enter Student Details',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentRegistrationForm(
                        programId: widget.programId,
                        programName: widget.programName,
                        convertToDetailedDocId: docId,
                        initialCount: data['studentCount'],
                      ),
                    ),
                  );
                },
              ),
            ],
            if (!widget.isLocked)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                  ),
                ),
                title: Text(
                  'Delete Registration',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteRegistration(docId);
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_circle_rounded,
                  color: Colors.green.shade700,
                ),
              ),
              title: Text(
                'Register Another',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentRegistrationForm(
                      programId: widget.programId,
                      programName: widget.programName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
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

  void _showEditBottomSheet(String docId, Map<String, dynamic> data) {
    if (widget.isLocked) return;
    final bool isCountOnly = data['isCountOnly'] == true;
    final String type = data['type']?.toString() ?? 'student';
    final bool isTeacher = type == 'teacher';

    final countController = TextEditingController(
      text: (data['studentCount'] ?? 1).toString(),
    );

    // Dynamic controllers for custom fields
    final fields = isTeacher ? _teacherFields : _studentFields;
    final customValues =
        data['customFieldValues'] as Map<String, dynamic>? ?? {};

    final Map<String, TextEditingController> controllers = {};
    for (final field in fields) {
      String initialValue = customValues[field.id]?.toString() ?? '';
      if (initialValue.isEmpty) {
        if (field.id == 'name') {
          initialValue = data['studentName']?.toString() ?? '';
        } else if (field.type == 'phone' || field.id == 'phone') {
          initialValue = data['studentPhone']?.toString() ?? '';
        } else if (field.id == 'address' || field.id == 'studentAddress') {
          initialValue = data['studentAddress']?.toString() ?? '';
        } else if (field.id == 'studentClass') {
          initialValue = data['studentClass']?.toString() ?? '';
        }
      }
      controllers[field.id] = TextEditingController(text: initialValue);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isCountOnly
                    ? (isTeacher ? 'Edit Teacher Count' : 'Edit Student Count')
                    : (isTeacher
                          ? 'Edit Teacher Details'
                          : 'Edit Student Details'),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 16),
              if (isCountOnly)
                TextField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isTeacher
                        ? 'Number of Teachers'
                        : 'Number of Students',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.people_alt_rounded),
                  ),
                )
              else ...[
                ...fields.map((field) {
                  final controller = controllers[field.id];
                  if (controller == null) return const SizedBox.shrink();

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
                    label = isTeacher ? 'Teacher Name' : 'Student Name';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (isCountOnly && countController.text.isEmpty) return;

                        setState(() => _isSaving = true);

                        try {
                          final Map<String, dynamic> updateData = {};
                          if (isCountOnly) {
                            updateData['studentCount'] =
                                int.tryParse(countController.text) ?? 1;
                          } else {
                            final Map<String, String> updatedCustomValues = {};
                            for (final field in fields) {
                              updatedCustomValues[field.id] =
                                  controllers[field.id]?.text.trim() ?? '';
                            }
                            updateData['customFieldValues'] =
                                updatedCustomValues;

                            // Sync fallback fields
                            String? fallbackName;
                            String? fallbackPhone;
                            String? fallbackAddress;
                            String? fallbackClass;

                            for (final field in fields) {
                              final val =
                                  controllers[field.id]?.text.trim() ?? '';
                              final fieldNameLower = field.name.toLowerCase();
                              final fieldIdLower = field.id.toLowerCase();

                              if (fieldIdLower == 'name' ||
                                  (fallbackName == null &&
                                      fieldNameLower.contains('name'))) {
                                fallbackName = val;
                              }
                              if (fieldIdLower == 'phone' ||
                                  field.type == 'phone' ||
                                  (fallbackPhone == null &&
                                      (fieldNameLower.contains('phone') ||
                                          fieldNameLower.contains('mobile') ||
                                          fieldNameLower.contains(
                                            'contact',
                                          )))) {
                                fallbackPhone = val;
                              }
                              if (fieldIdLower == 'address' ||
                                  (fallbackAddress == null &&
                                      fieldNameLower.contains('address'))) {
                                fallbackAddress = val;
                              }
                              if (fieldIdLower == 'class' ||
                                  fieldIdLower == 'studentclass' ||
                                  (fallbackClass == null &&
                                      fieldNameLower.contains('class'))) {
                                fallbackClass = val;
                              }
                            }

                            updateData['studentName'] = fallbackName ?? '';
                            updateData['studentPhone'] = fallbackPhone ?? '';
                            if (fallbackAddress != null) {
                              updateData['studentAddress'] = fallbackAddress;
                            }
                            if (fallbackClass != null) {
                              updateData['studentClass'] = fallbackClass;
                            }
                          }

                          await FirebaseFirestore.instance
                              .collection('program_registrations')
                              .doc(docId)
                              .update(updateData);

                          if (mounted) {
                            Navigator.pop(ctx);
                            await _showStatusDialog(
                              context: context,
                              isSuccess: true,
                              title: "Updated!",
                              message:
                                  "Registration details updated successfully.",
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Save Changes",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.programName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade700],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'View Registration History',
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegistrationHistoryScreen(
                    programId: widget.programId,
                    programName: widget.programName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .where('schoolUserId', isEqualTo: user!.uid)
            .where('programName', isEqualTo: widget.programName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          bool hasPaid = true;
          String? paymentScreenshotUrl;
          int totalRegistrants = 0;
          int unpaidRegistrants = 0;
          int paidRegistrants = 0;
          List<QueryDocumentSnapshot> unpaidDocs = [];

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final isCountOnly = data['isCountOnly'] == true;
            final count = isCountOnly ? (data['studentCount'] as int? ?? 1) : 1;
            totalRegistrants += count;

            final screenshot = data['paymentScreenshotUrl']?.toString();
            if (screenshot != null && screenshot.isNotEmpty) {
              paymentScreenshotUrl = screenshot;
              paidRegistrants += count;
            } else {
              hasPaid = false;
              unpaidRegistrants += count;
              unpaidDocs.add(doc);
            }
          }

          // If no documents exist, hasPaid shouldn't show as true
          if (docs.isEmpty) {
            hasPaid = false;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_paymentDetails != null &&
                  _paymentDetails!.isRequired &&
                  docs.isNotEmpty)
                _buildPaymentStatusCard(
                  context,
                  hasPaid ? docs : unpaidDocs,
                  hasPaid ? totalRegistrants : unpaidRegistrants,
                  hasPaid,
                  paymentScreenshotUrl,
                  paidRegistrants: paidRegistrants,
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final bool isCountOnly = data['isCountOnly'] == true;
                    final int studentCount = data['studentCount'] ?? 1;
                    final String itemType =
                        data['type']?.toString() ?? 'student';
                    final bool isItemTeacher = itemType == 'teacher';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isCountOnly
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          child: Icon(
                            isCountOnly
                                ? Icons.groups_rounded
                                : Icons.person_rounded,
                            color: isCountOnly
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                        title: Text(
                          isCountOnly
                              ? '$studentCount ${isItemTeacher ? 'Teacher' : 'Student'}${studentCount == 1 ? '' : 's'} (Count Only)'
                              : (data['studentName'] ?? 'Unknown'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: isCountOnly
                            ? Text(
                                'No details provided',
                                style: GoogleFonts.poppins(),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['studentPhone'] ?? 'No Phone',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _showViewDetailsDialog(data),
                                    child: Text(
                                      'View Details',
                                      style: GoogleFonts.poppins(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        trailing: widget.isLocked
                            ? const Icon(Icons.lock, color: Colors.grey)
                            : IconButton(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.blue.shade900,
                                ),
                                onPressed: () => _showActionSheet(doc.id, data),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registration History Screen
// ---------------------------------------------------------------------------
class RegistrationHistoryScreen extends StatelessWidget {
  final String programId;
  final String programName;

  const RegistrationHistoryScreen({
    super.key,
    required this.programId,
    required this.programName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Program Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.indigo.shade800],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .where('programId', isEqualTo: programId)
            .where(
              'schoolUserId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 80,
                    color: Colors.blueGrey.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Registrations Found',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ],
              ),
            );
          }
          final docs = snapshot.data!.docs;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programName,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Registrations: ${docs.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isCountOnly = data['isCountOnly'] == true;
                    final int studentCount = data['studentCount'] ?? 1;
                    final name = isCountOnly
                        ? '$studentCount ${data['type'] == 'teacher' ? 'Teacher' : 'Student'}${studentCount == 1 ? '' : 's'} (Count Only)'
                        : (data['studentName']?.toString() ?? 'N/A');
                    final type = data['type']?.toString() ?? 'student';
                    final isTeacher = type == 'teacher';
                    final status = data['status']?.toString() ?? 'pending';
                    final dateStr = data['registrationDate']?.toString() ?? '';

                    String displayStatus = status;
                    Color statusColor = Colors.orange;
                    if (status == 'pending_parish' || status == 'pending') {
                      displayStatus = 'Pending Approval';
                      statusColor = Colors.orange;
                    } else if (status == 'locked' || status == 'approved') {
                      displayStatus = 'Approved & Locked';
                      statusColor = Colors.green;
                    } else if (status == 'rejected') {
                      displayStatus = 'Rejected';
                      statusColor = Colors.red;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isTeacher
                              ? Colors.purple.shade50
                              : Colors.blue.shade50,
                          child: Icon(
                            isCountOnly
                                ? Icons.groups_rounded
                                : Icons.person_rounded,
                            color: isTeacher
                                ? Colors.purple.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.blueGrey.shade800,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${isTeacher ? 'Teacher' : 'Student'} Registration',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade500,
                                ),
                              ),
                              if (dateStr.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.blueGrey.shade400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            displayStatus.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User Registration History Screen
// ---------------------------------------------------------------------------
class UserRegistrationHistoryScreen extends StatelessWidget {
  final String userId;

  const UserRegistrationHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Registration History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.indigo.shade800],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('program_registrations')
            .where('schoolUserId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 80,
                    color: Colors.blueGrey.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Registration History',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your past registrations will appear here.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blueGrey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group registrations by programId to display programs cleanly
          final docs = snapshot.data!.docs;
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          final Map<String, String> programNames = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final progId = data['programId']?.toString() ?? 'unknown';
            final progName =
                data['programName']?.toString() ?? 'Unnamed Program';

            programNames[progId] = progName;
            if (!grouped.containsKey(progId)) {
              grouped[progId] = [];
            }
            grouped[progId]!.add(data);
          }

          final programIds = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: programIds.length,
            itemBuilder: (context, index) {
              final progId = programIds[index];
              final progName = programNames[progId] ?? 'Unnamed Program';
              final registrations = grouped[progId]!;

              // Count teachers and students
              int teachers = 0;
              int students = 0;
              for (var reg in registrations) {
                final isCountOnly = reg['isCountOnly'] == true;
                final count = isCountOnly
                    ? (reg['studentCount'] as int? ?? 1)
                    : 1;
                final type = reg['type']?.toString() ?? 'student';
                if (type == 'teacher') {
                  teachers += count;
                } else {
                  students += count;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: Colors.indigo.shade800,
                      collapsedIconColor: Colors.blueGrey.shade400,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      title: Text(
                        progName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            if (students > 0)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.school_rounded,
                                      size: 14,
                                      color: Colors.blue.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$students Student${students == 1 ? "" : "s"}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (teachers > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: 14,
                                      color: Colors.purple.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$teachers Teacher${teachers == 1 ? "" : "s"}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      children: [
                        Container(
                          color: Colors.grey.shade50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...registrations.map((reg) {
                                final isCountOnly = reg['isCountOnly'] == true;
                                final count = reg['studentCount'] ?? 1;
                                final type =
                                    reg['type']?.toString() ?? 'student';
                                final isTeacher = type == 'teacher';
                                final status =
                                    reg['status']?.toString() ?? 'pending';
                                final name = isCountOnly
                                    ? '$count ${isTeacher ? 'Teacher' : 'Student'}${count == 1 ? '' : 's'} (Count Only)'
                                    : (reg['studentName'] ?? 'Unnamed');

                                String displayStatus = status;
                                Color statusColor = Colors.orange;
                                if (status == 'pending_parish' ||
                                    status == 'pending') {
                                  displayStatus = 'Pending Approval';
                                  statusColor = Colors.orange;
                                } else if (status == 'locked' ||
                                    status == 'approved') {
                                  statusColor = Colors.green;
                                } else if (status == 'rejected') {
                                  statusColor = Colors.red;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isTeacher
                                            ? Colors.purple.shade50
                                            : Colors.blue.shade50,
                                        radius: 18,
                                        child: Icon(
                                          isCountOnly
                                              ? Icons.groups_rounded
                                              : Icons.person_outline_rounded,
                                          size: 18,
                                          color: isTeacher
                                              ? Colors.purple.shade700
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.blueGrey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isTeacher
                                                  ? 'Teacher Registration'
                                                  : 'Student Registration',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.blueGrey.shade400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          displayStatus.toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RegistrationHistoryScreen(
                                        programId: progId,
                                        programName: progName,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade900,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'View Full Program Details',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
