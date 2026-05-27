import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

// 1. The main generation function
Future<Uint8List> generateEventReport(
  Map<String, dynamic> eventData, {
  Map<String, String>? preFetchedAssets,
  required PdfPageFormat format,
}) async {
  // --- DATA PREPARATION ---
  final title = eventData['title'] ?? 'Event Report';
  final place = eventData['place'] ?? 'N/A';
  final description = eventData['description'] ?? 'No description provided.';
  final category = (eventData['category'] ?? 'N/A').toUpperCase();

  final date =
      eventData['timestamp'] != null && eventData['timestamp'] is Timestamp
      ? DateFormat(
          'MMMM d, yyyy, h:mm a',
        ).format(eventData['timestamp'].toDate())
      : 'Date Unavailable';

  final creatorSchoolName = eventData['creatorSchoolName'] ?? 'N/A';
  final imageUrl = eventData['imageUrl'] ?? '';

  // --- LOGO AND HERO IMAGE ASSETS ---
  String logoBase64 = preFetchedAssets?['logo'] ?? '';
  String heroBase64 = preFetchedAssets?['hero'] ?? '';

  // If assets were not pre-fetched, load them now (fallback)
  if (preFetchedAssets == null) {
    try {
      final ByteData logoData = await rootBundle.load(
        'assets/images/reportlogo.jpg',
      );
      logoBase64 = base64Encode(logoData.buffer.asUint8List());
    } catch (e) {
      print('Error loading logo for PDF: $e');
    }

    if (imageUrl.isNotEmpty) {
      try {
        final Uri? uri = Uri.tryParse(imageUrl);
        if (uri != null && uri.hasScheme) {
          final response = await http
              .get(uri)
              .timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            heroBase64 = base64Encode(response.bodyBytes);
          }
        }
      } catch (e) {
        print('Error fetching network image for PDF: $e');
      }
    }
  }

  final String reportGeneratedOn = DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime.now());

  // --- HTML CONSTRUCT (TABLE-BASED FOR MAXIMUM COMPATIBILITY) ---
  final String htmlContent =
      '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    /* COMBINED FONT IMPORT FOR SPEED */
    @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@400;700;900&family=Noto+Sans+Malayalam:wght@400;700&display=swap');

    body {
      padding: 30px;
      color: #1a1a1a;
      background: #ffffff;
      font-family: 'Outfit', 'Noto Sans Malayalam', sans-serif;
      margin: 0;
    }

    /* COMPATIBLE TABLE STYLES */
    table { width: 100%; border-collapse: collapse; border: none; }
    td { vertical-align: top; }

    /* HEADER */
    .header-table { border-bottom: 2px solid #f0f0f0; padding-bottom: 15px; margin-bottom: 25px; }
    .logo-td { width: 80px; }
    .logo-img { width: 80px; height: 80px; object-fit: contain; }
    .title-td { text-align: right; }
    .main-title { font-size: 32px; font-weight: 900; color: #0D47A1; margin: 0; letter-spacing: 2px; }
    .sub-brand { font-size: 10px; font-weight: 700; color: #666; }
    .malayalam-brand { font-size: 16px; font-weight: 700; color: #333; margin-top: 4px; }

    /* HERO */
    .hero-container { width: 100%; margin-bottom: 25px; text-align: center; background: #f0f0f0; border-radius: 15px; overflow: hidden; }
    .hero-img { width: 100%; max-height: 450px; object-fit: contain; }

    /* SECTION TITLE */
    .section-title { font-size: 24px; font-weight: 800; color: #0D47A1; margin-bottom: 20px; border-left: 5px solid #0D47A1; padding-left: 15px; }

    /* INFO GRID (USING TABLE) */
    .info-table { margin-bottom: 25px; }
    .card-td { width: 48%; padding: 15px; background: #f8f9fa; border-radius: 12px; border: 1px solid #eee; }
    .spacer-td { width: 4%; }
    .card-title { font-size: 13px; font-weight: 900; color: #0D47A1; text-transform: uppercase; margin-bottom: 10px; border-bottom: 1px solid #ddd; padding-bottom: 4px; }
    .label { font-size: 9px; font-weight: 700; color: #888; text-transform: uppercase; margin-top: 6px; }
    .value { font-size: 13px; font-weight: 600; color: #333; margin-bottom: 4px; }

    /* DESCRIPTION */
    .desc-title { font-size: 15px; font-weight: 800; color: #1a1a1a; text-transform: uppercase; margin-bottom: 10px; }
    .desc-body { font-size: 14px; color: #444; line-height: 1.5; white-space: pre-wrap; text-align: justify; }

    /* FOOTER */
    .footer { margin-top: 40px; padding-top: 15px; border-top: 1px solid #efefef; text-align: center; color: #999; font-size: 10px; }
  </style>
</head>
<body>

  <!-- HEADER -->
  <table class="header-table">
    <tr>
      <td class="logo-td">
        ${logoBase64.isNotEmpty ? '<img src="data:image/jpeg;base64,$logoBase64" class="logo-img" />' : ''}
      </td>
      <td class="title-td">
        <div class="main-title">SUVARA</div>
        <div class="sub-brand">CENTRE FOR CATECHESIS, EPARCHY OF KANJIRAPALLY</div>
      </td>
    </tr>
  </table>

  <div class="section-title">$title</div>

  <!-- HERO IMAGE -->
  ${heroBase64.isNotEmpty ? '<div class="hero-container"><img src="data:image/jpeg;base64,$heroBase64" class="hero-img" /></div>' : ''}

  <!-- INFO GRID -->
  <table class="info-table">
    <tr>
      <!-- LEFT CARD -->
      <td class="card-td">
        <div class="card-title">Event Details</div>
        <div class="label">Date & Time</div>
        <div class="value">$date</div>
        <div class="label">Venue/Place</div>
        <div class="value">$place</div>
        <div class="label">Category</div>
        <div class="value">$category</div>
      </td>
      
      <td class="spacer-td"></td>

      <!-- RIGHT CARD -->
      <td class="card-td">
        <div class="card-title">Report Metadata</div>
        <div class="label">Report Generated</div>
        <div class="value">$reportGeneratedOn</div>
        <div class="label">Created By</div>
        <div class="value">$creatorSchoolName</div>
      </td>
    </tr>
  </table>

  <!-- DESCRIPTION -->
  <div class="desc-title">Event Summary & Description</div>
  <div class="desc-body">$description</div>

  <!-- FOOTER -->
  <div class="footer">
    &copy; ${DateTime.now().year} SUVARA | Eparchy of Kanjirapally. All Rights Reserved.
    <br/>
    -- End of Official Digital Report --
  </div>

</body>
</html>
''';

  return await Printing.convertHtml(
    format: format, // Use formatting passed from print listener
    html: htmlContent,
  );
}

/// Pre-fetches the logo and hero image to improve PDF generation speed
Future<Map<String, String>> preFetchReportAssets(
  Map<String, dynamic> eventData,
) async {
  String logoBase64 = '';
  String heroBase64 = '';

  try {
    // Load Logo
    try {
      final ByteData logoData = await rootBundle.load(
        'assets/images/reportlogo.jpg',
      );
      logoBase64 = base64Encode(logoData.buffer.asUint8List());
    } catch (e) {
      print('Pre-fetch: Error loading logo: $e');
    }

    // Load Hero Image
    final imageUrl = eventData['imageUrl'] ?? '';
    if (imageUrl.isNotEmpty) {
      try {
        final Uri? uri = Uri.tryParse(imageUrl);
        if (uri != null && uri.hasScheme) {
          final response = await http
              .get(uri)
              .timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            heroBase64 = base64Encode(response.bodyBytes);
          }
        }
      } catch (e) {
        print('Pre-fetch: Error fetching network image: $e');
      }
    }
  } catch (e) {
    print('Major pre-fetch failure: $e');
  }

  return {'logo': logoBase64, 'hero': heroBase64};
}
