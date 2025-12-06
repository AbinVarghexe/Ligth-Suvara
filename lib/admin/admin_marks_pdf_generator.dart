import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class AdminMarksPdfGenerator {
  static Future<void> generateAndOpen({
    required String parish,
    required String sundaySchool,
    required String animatorName,
    required String year,
    required Map<String, dynamic> marks,
    required Map<String, String> questionMap,
    required Map<String, int> maxMarkMap,
    required List<String> sortedQuestionIds,
  }) async {
    final pdf = pw.Document();

    // Load Assets (Logos & Fonts)
    final logoImage = await _loadAsset('assets/images/suvara logo wbg5.jpg');
    final font = await PdfGoogleFonts.notoSansMalayalamRegular();

    // Calculate Total
    int totalScore = 0;
    int maxTotalScore = 0;
    final List<List<String>> tableData = [];
    int index = 1;

    // Use sortedQuestionIds to iterate in correct order
    for (String key in sortedQuestionIds) {
      final String questionText = questionMap[key] ?? 'Unknown Question ($key)';
      final int maxMark = maxMarkMap[key] ?? 10;
      final dynamic rawValue = marks[key];

      // If no mark is awarded (e.g. absent/null), treat as 0 or handle as needed
      final int awardedMark = rawValue is int
          ? rawValue
          : int.tryParse(rawValue?.toString() ?? '0') ?? 0;

      totalScore += awardedMark;
      maxTotalScore += maxMark;

      tableData.add([
        index.toString(),
        questionText,
        maxMark.toString(),
        awardedMark.toString(),
      ]);
      index++;
    }

    // Parse Year for Range
    final int parsedYear = int.tryParse(year) ?? DateTime.now().year;
    final String yearRange = '$parsedYear - ${parsedYear + 1}';

    // Define PDF Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.Image(logoImage),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'SUVARA',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'CENTRE FOR CATECHESIS, EPARCHY OF KANJIRAPALLY',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Viswasajeevitha Parisheelanam',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Edavaka Vilayiruthal $yearRange',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // --- INFO SECTION ---
              // --- INFO SECTION ---
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(120), // Fixed width for labels
                  1: const pw.FlexColumnWidth(),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          'Parish:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(parish),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          'Sunday School Name:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(sundaySchool),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          'Animator:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(animatorName),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              // Align Total Score Box to right like in the image
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 100,
                  height: 40,
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Total Score',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '$totalScore / $maxTotalScore',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // --- TABLE ---
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                },
                headers: ['No.', 'Question', 'Max Mark', 'Mark Awarded'],
                data: tableData,
                columnWidths: {
                  0: const pw.FixedColumnWidth(30), // No.
                  1: const pw.FlexColumnWidth(4), // Question
                  2: const pw.FixedColumnWidth(60), // Max
                  3: const pw.FixedColumnWidth(60), // Awarded
                },
              ),
            ],
          );
        },
      ),
    );

    // Save and Open
    try {
      final output = await getTemporaryDirectory();
      // Use parish in filename
      final fileName =
          "marks_${parish.replaceAll(' ', '_')}_${sundaySchool.replaceAll(' ', '_')}.pdf";
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      print("Error saving/opening PDF: $e");
    }
  }

  static Future<pw.ImageProvider?> _loadAsset(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      print("Error loading asset $path: $e");
      return null;
    }
  }
}
