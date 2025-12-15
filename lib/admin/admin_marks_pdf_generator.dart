import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class AdminMarksPdfGenerator {
  static Future<void> generateAndOpen({
    required String parish,
    required String sundaySchool,
    required String animatorName,
    required String year,
    required Map<String, dynamic> marks,
    required String remarks,
    required Map<String, String> questionMap,
    required Map<String, int> maxMarkMap,
    required List<String> sortedQuestionIds,
  }) async {
    // 1. Calculate scores and prepare table rows
    int totalScore = 0;
    int maxTotalScore = 0;

    // Build table rows HTML
    StringBuffer rowsBuffer = StringBuffer();
    int index = 1;

    for (String key in sortedQuestionIds) {
      if (!marks.containsKey(key)) continue;

      final String questionText = questionMap[key] ?? 'Unknown Question ($key)';
      final int maxMark = maxMarkMap[key] ?? 10;
      final dynamic rawValue = marks[key];

      final int awardedMark = rawValue is int
          ? rawValue
          : int.tryParse(rawValue?.toString() ?? '0') ?? 0;

      totalScore += awardedMark;
      maxTotalScore += maxMark;

      rowsBuffer.writeln('''
        <tr>
          <td style="text-align: center;">$index</td>
          <td>$questionText</td>
          <td style="text-align: center;">$maxMark</td>
          <td style="text-align: center;">$awardedMark</td>
        </tr>
      ''');
      index++;
    }

    final int parsedYear = int.tryParse(year) ?? DateTime.now().year;
    final String yearRange = '$parsedYear - ${parsedYear + 1}';

    // 2. Load Logo and convert to Base64
    String logoHtml = '';
    try {
      final ByteData bytes = await rootBundle.load(
        'assets/images/reportlogo.jpg',
      );
      final Uint8List list = bytes.buffer.asUint8List();
      final String base64Image = base64Encode(list);
      // Ensure we use the correct Data URI format
      logoHtml =
          '<img src="data:image/jpeg;base64,$base64Image" style="width: 100%; height: auto;" />';
    } catch (e) {
      print('Error loading logo: $e');
    }

    // 3. Construct HTML
    // We use a Google Font import for Noto Sans Malayalam to ensuring shaping works.
    final String htmlContent =
        '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Malayalam:wght@400;700&display=swap');
        
        body {
          font-family: 'Noto Sans Malayalam', sans-serif;
          padding: 40px;
          color: #000;
        }
        .header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
        }
        .logo-section {
          width: 80px;
          height: 80px;
        }
        .title-section {
          text-align: center;
          flex-grow: 1;
        }
        h1 {
          font-size: 24px;
          font-weight: bold;
          margin: 0;
        }
        .subtitle {
          font-size: 10px;
          margin: 2px 0;
        }
        .malayalam-title {
          font-size: 16px;
          font-weight: bold;
          margin: 5px 0;
        }
        .year-title {
          font-size: 14px;
        }
        
        .info-table {
          width: 100%;
          margin-bottom: 20px;
          border-collapse: collapse;
        }
        .info-table td {
          padding: 5px;
          font-size: 14px;
        }
        .label {
          font-weight: bold;
          width: 150px;
        }
        
        .score-box {
          float: right;
          border: 1px solid #000;
          padding: 10px;
          text-align: center;
          width: 120px;
          margin-bottom: 20px;
        }
        .score-label {
          font-size: 10px;
          display: block;
        }
        .score-value {
          font-size: 18px;
          font-weight: bold;
        }

        .marks-table {
          width: 100%;
          border-collapse: collapse;
          margin-top: 20px;
          clear: both;
        }
        .marks-table th, .marks-table td {
          border: 1px solid #000;
          padding: 8px;
          font-size: 12px;
        }
        .marks-table th {
          background-color: #f0f0f0;
          font-weight: bold;
        }
      </style>
    </head>
    <body>

      <div class="header">
        <div class="logo-section">
          $logoHtml
        </div>
        <div class="title-section">
          <h1>SUVARA</h1>
          <div class="subtitle">CENTRE FOR CATECHESIS, EPARCHY OF KANJIRAPALLY</div>
          <div class="malayalam-title">വിശ്വാസജീവിത പരിശീലനം</div>
          <div class="year-title">ഇടവകതല വിലയിരുത്തൽ $yearRange</div>
        </div>
      </div>

      <table class="info-table">
        <tr>
          <td class="label">Parish:</td>
          <td>$parish</td>
        </tr>
        <tr>
          <td class="label">Sunday School:</td>
          <td>$sundaySchool</td>
        </tr>
        <tr>
          <td class="label">Animator:</td>
          <td>$animatorName</td>
        </tr>
        <tr>
          <td class="label">Date:</td>
          <td>${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}</td>
        </tr>
      </table>

      <div class="score-box">
        <span class="score-label">Total Score</span>
        <span class="score-value">$totalScore / $maxTotalScore</span>
      </div>

      <table class="marks-table">
        <thead>
          <tr>
            <th style="width: 40px;">No.</th>
            <th>Question</th>
            <th style="width: 80px;">Max Mark</th>
            <th style="width: 80px;">Mark Awarded</th>
          </tr>
        </thead>
        <tbody>
          ${rowsBuffer.toString()}
        </tbody>
      </table>

      ${remarks.isNotEmpty ? '''
      <div style="margin-top: 20px; padding: 10px; border: 1px solid #ddd; background-color: #f9f9f9;">
        <span style="font-weight: bold; font-size: 12px; display: block; margin-bottom: 5px;">General Remarks:</span>
        <span style="font-size: 12px;">$remarks</span>
      </div>
      ''' : ''}
    </body>
    </html>
    ''';

    // 4. Print / Generate PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return await Printing.convertHtml(format: format, html: htmlContent);
      },
      name: 'Marks_${parish}_$year',
    );
  }
}
