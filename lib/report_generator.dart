import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

// 1. The main generation function
Future<Uint8List> generateEventReport(Map<String, dynamic> eventData) async {
  final pdf = pw.Document();

  // --- DATA PREPARATION ---
  final title = eventData['title'] ?? 'Event Report';
  final place = eventData['place'] ?? 'N/A';
  final description = eventData['description'] ?? 'No description provided.';

  // --- 1. GET THE CATEGORY DATA ---
  final category = (eventData['category'] ?? 'N/A').toUpperCase();

  // ⭐️ FIX: Use a PDF-safe date format that includes the time ⭐️
  final date = eventData['timestamp'] != null && eventData['timestamp'] is Timestamp
      ? DateFormat('MMMM d, yyyy, h:mm a').format(eventData['timestamp'].toDate())
      : 'Date Unavailable';

  final creatorSchoolName = eventData['creatorSchoolName'] ?? 'N/A';
  final imageUrl = eventData['imageUrl'] ?? '';

  // --- LOAD ASSETS FOR PDF ---
  pw.ImageProvider? eventImage;
  if (imageUrl.isNotEmpty) {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        eventImage = pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      print('Could not fetch network image for PDF: $e');
    }
  }

  // --- PDF PAGE BUILDING ---
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (pw.Context context) => _buildHeader(title),
      footer: (pw.Context context) => _buildFooter(context),

      build: (pw.Context context) => [
        if (eventImage != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 25),
            child: pw.Container(
              height: 200,
              width: double.infinity,
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(10),
                image: pw.DecorationImage(
                  image: eventImage,
                  fit: pw.BoxFit.contain,
                ),
                border: pw.Border.all(color: PdfColors.blueGrey100, width: 2),
              ),
            ),
          ),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _buildDetailColumn('Event Details', [
                _buildDetailRow('Date & Time', date), // Use the corrected date and time
                _buildDetailRow('Venue/Place', place),
                _buildDetailRow('Category', category),
              ]),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: _buildDetailColumn('Creation Info', [
                _buildDetailRow(
                  'Report Generated',
                  DateFormat('yyyy-MM-dd').format(DateTime.now()),
                ),
                _buildDetailRow('Created By', creatorSchoolName),
              ]),
            ),
          ],
        ),

        pw.SizedBox(height: 30),

        pw.Header(
          level: 1,
          text: 'Event Description',
          textStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 16,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.Divider(color: PdfColors.grey300, thickness: 1),
        pw.SizedBox(height: 10),
        pw.Paragraph(
          text: description,
          textAlign: pw.TextAlign.justify,
          style: const pw.TextStyle(lineSpacing: 5),
        ),

        pw.SizedBox(height: 50),
        pw.Center(
          child: pw.Text(
            '-- End of Report --',
            style: pw.TextStyle(
              color: PdfColors.grey,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _buildHeader(String eventTitle) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 20),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Sunday School Event Report',
          style: pw.TextStyle(
            color: PdfColors.blue700,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          eventTitle,
          style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 14),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Divider(color: PdfColors.grey400),
        ),
      ],
    ),
  );
}

pw.Widget _buildDetailColumn(String title, List<pw.Widget> details) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.blue50,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
            color: PdfColors.blue800,
          ),
        ),
        pw.Divider(height: 10, color: PdfColors.blue200),
        ...details,
      ],
    ),
  );
}

pw.Widget _buildDetailRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildFooter(pw.Context context) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 20),
    child: pw.Text(
      'Page ${context.pageNumber} of ${context.pagesCount}',
      style: const pw.TextStyle(color: PdfColors.grey, fontSize: 8),
    ),
  );
}
