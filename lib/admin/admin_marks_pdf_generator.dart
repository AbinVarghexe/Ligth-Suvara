import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class AdminMarksPdfGenerator {
  static String _intToRoman(int number) {
    if (number <= 0) return number.toString();
    final Map<int, String> romanMap = {
      1000: 'M',
      900: 'CM',
      500: 'D',
      400: 'CD',
      100: 'C',
      90: 'XC',
      50: 'L',
      40: 'XL',
      10: 'X',
      9: 'IX',
      5: 'V',
      4: 'IV',
      1: 'I',
    };
    String result = '';
    romanMap.forEach((key, value) {
      while (number >= key) {
        result += value;
        number -= key;
      }
    });
    return result;
  }

  static Future<void> generateAndOpen({
    required String parish,
    required String sundaySchool,
    required String animatorName,
    required String year,
    required Map<String, dynamic> marks,
    required Map<String, dynamic> textValues,
    required String remarks,
    required Map<String, String> questionMap,
    required Map<String, int?> maxMarkMap,
    required Map<String, String> partMap,
    required Map<String, String> partTitleMap,
    required List<String> sortedQuestionIds,
  }) async {
    // 1. Calculate scores and prepare table rows
    int totalScore = 0;
    int maxTotalScore = 0;
    bool hasUnlimited = false;

    // Build table rows HTML
    StringBuffer rowsBuffer = StringBuffer();
    int index = 1;
    String currentPart = '';

    final mainQuestionIds = sortedQuestionIds
        .where((q) => !q.contains('_sub_'))
        .toList();

    for (String mainKey in mainQuestionIds) {
      final String part = partMap[mainKey] ?? '';
      final String partTitle = partTitleMap[mainKey] ?? '';

      if (part.isNotEmpty && part != currentPart) {
        currentPart = part;
        index = 1; // Reset numbering for new part

        // Convert the part string to a Roman numeral if it's a valid integer
        final int? parsedPart = int.tryParse(part);
        final String formattedPart = parsedPart != null
            ? _intToRoman(parsedPart)
            : part;

        final String displayTitle = partTitle.isNotEmpty
            ? '$formattedPart. $partTitle'
            : formattedPart;
        rowsBuffer.writeln('''
          <tr>
            <td colspan="4" style="background-color: #f0f0f0; font-weight: bold; padding: 10px; text-align: left;">
              $displayTitle
            </td>
          </tr>
        ''');
      }
      final String questionText =
          questionMap[mainKey] ?? 'Unknown Question ($mainKey)';
      final int? maxMark = maxMarkMap[mainKey];
      final String maxMarkStr = maxMark != null ? maxMark.toString() : '';

      final subQIds = sortedQuestionIds
          .where((k) => k.startsWith('${mainKey}_sub_'))
          .toList();

      if (subQIds.isEmpty) {
        final dynamic rawValue = marks[mainKey];
        if (rawValue == null) continue; // Skip unanswered questions

        final int awardedMark = rawValue is int
            ? rawValue
            : int.tryParse(rawValue?.toString() ?? '0') ?? 0;
        totalScore += awardedMark;
        if (maxMark != null) {
          maxTotalScore += maxMark;
        } else {
          hasUnlimited = true;
        }

        rowsBuffer.writeln('''
          <tr>
            <td style="text-align: center;">$index</td>
            <td>$questionText</td>
            <td style="text-align: center;">$maxMarkStr</td>
            <td style="text-align: center;">$awardedMark</td>
          </tr>
        ''');
      } else {
        // Main question with sub-fields
        final answeredSubKeys = subQIds.where((subKey) {
          final mark = marks[subKey];
          final textVal = textValues[subKey];

          // Strict check: mark must be a non-null number
          bool hasMark = mark != null && (mark is int || mark is double);
          // Text must have content after trimming
          bool hasText =
              textVal != null && textVal.toString().trim().isNotEmpty;

          return hasMark || hasText;
        }).toList();

        if (answeredSubKeys.isEmpty) {
          continue; // Skip main question if all subfields are unanswered
        }

        rowsBuffer.writeln('''
          <tr>
            <td style="text-align: center;">$index</td>
            <td colspan="3" style="font-weight: bold;">$questionText</td>
          </tr>
        ''');

        for (String subKey in answeredSubKeys) {
          final String subText = questionMap[subKey] ?? '';
          final int? subMaxMark = maxMarkMap[subKey];
          final String subMaxMarkStr = subMaxMark != null
              ? subMaxMark.toString()
              : '';

          final textVal = textValues[subKey];
          final String displaySubText =
              textVal != null && textVal.toString().isNotEmpty
              ? '$subText - <i>${textVal.toString()}</i>'
              : subText;

          final dynamic rawValue = marks[subKey];
          final String awardedStr = rawValue != null
              ? rawValue.toString()
              : '-';
          final int awardedMark = rawValue is int
              ? rawValue
              : int.tryParse(rawValue?.toString() ?? '0') ?? 0;

          totalScore += awardedMark;
          if (subMaxMark != null) {
            maxTotalScore += subMaxMark;
          } else {
            hasUnlimited = true;
          }

          rowsBuffer.writeln('''
            <tr>
              <td></td>
              <td style="padding-left: 20px;">$displaySubText</td>
              <td style="text-align: center;">$subMaxMarkStr</td>
              <td style="text-align: center;">$awardedStr</td>
            </tr>
          ''');
        }
      }
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
        <span class="score-value">$totalScore</span>
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
