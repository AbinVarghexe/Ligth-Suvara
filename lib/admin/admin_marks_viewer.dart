import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sundayschool_app/admin/admin_marks_pdf_generator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminMarksViewer extends StatefulWidget {
  const AdminMarksViewer({super.key});

  @override
  State<AdminMarksViewer> createState() => _AdminMarksViewerState();
}

class _AdminMarksViewerState extends State<AdminMarksViewer> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedYear = DateTime.now().year.toString();

  // Maps to store Question ID -> Question Text / Max Mark
  Map<String, String> _questionMap = {};
  Map<String, int> _maxMarkMap = {};
  bool _isLoadingQuestions = true;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final snapshot = await _firestore
          .collection('questions')
          .orderBy('order')
          .get();
      final qMap = <String, String>{};
      final mMap = <String, int>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        qMap[doc.id] = data['text'] ?? 'Unknown Question';
        mMap[doc.id] = data['maxMark'] ?? 10;
      }

      if (mounted) {
        setState(() {
          _questionMap = qMap;
          _maxMarkMap = mMap;
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      print("Error fetching questions: $e");
      if (mounted) setState(() => _isLoadingQuestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
        title: Text(
          'View Marks',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Select Year:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      isDense: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.blue.shade900,
                      ),
                      items: List.generate(5, (index) {
                        final year = (DateTime.now().year - index).toString();
                        return DropdownMenuItem(
                          value: year,
                          child: Text(
                            year,
                            style: GoogleFonts.poppins(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedYear = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingQuestions) const LinearProgressIndicator(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('marks')
                  .where('year', isEqualTo: _selectedYear)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No marks found for $_selectedYear',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    // Extract new fields, fallback to old or defaults
                    final parish = data['parish'] ?? 'Unknown Parish';
                    final sundaySchool =
                        data['sundaySchool'] ??
                        data['userName'] ??
                        'Unknown SS';
                    final unitId = data['unitId'] ?? data['userId'] ?? 'N/A';
                    final animatorName =
                        data['animatorName'] ?? 'Unknown Animator';

                    final marks = data['marks'] as Map<String, dynamic>? ?? {};
                    final totalMarks = marks.values.fold(
                      0,
                      (sum, val) => sum + (val as int),
                    );
                    final pdfUrl = data['pdfUrl'];

                    return Card(
                      elevation: 2,
                      shadowColor: Colors.blue.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          _showMarksDialog(
                            context,
                            parish,
                            sundaySchool,
                            unitId,
                            animatorName,
                            marks,
                            pdfUrl,
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.school,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sundaySchool,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        Text(
                                          parish,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (pdfUrl != null)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.picture_as_pdf,
                                        color: Colors.red.shade400,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Animator',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        Text(
                                          animatorName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'Total: $totalMarks',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  void _showMarksDialog(
    BuildContext context,
    String parish,
    String sundaySchool,
    String unitId,
    String animatorName,
    Map<String, dynamic> marks,
    String? pdfUrl,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sundaySchool,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              parish,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Animator: $animatorName',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...marks.entries.map((e) {
                final qText =
                    _questionMap[e.key] ?? 'Unknown Question (${e.key})';
                final maxMark = _maxMarkMap[e.key] ?? 10;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          qText,
                          style: GoogleFonts.inter(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${e.value} / $maxMark',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),

              if (pdfUrl != null) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.description_outlined),
                    label: Text(
                      'View Answer Sheet',
                      style: GoogleFonts.poppins(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse(pdfUrl);
                      try {
                        if (!await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        )) {
                          // Try without specific mode if external fails
                          if (!await launchUrl(url)) {
                            throw 'Could not launch $url';
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open PDF: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('Download Report', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              AdminMarksPdfGenerator.generateAndOpen(
                parish: parish,
                sundaySchool: sundaySchool,
                animatorName: animatorName,
                year: _selectedYear,
                marks: marks,
                questionMap: _questionMap,
                maxMarkMap: _maxMarkMap,
                sortedQuestionIds: _questionMap.keys.toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
