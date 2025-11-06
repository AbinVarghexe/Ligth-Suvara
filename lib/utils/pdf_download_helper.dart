import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';

/// Utility class for handling PDF downloads
class PDFDownloadHelper {
  /// Download PDF bytes to device storage
  static Future<String?> downloadPDF(
    Uint8List pdfBytes,
    String fileName, {
    BuildContext? context,
  }) async {
    try {
      // Get the Downloads directory (Android)
      Directory? directory;

      if (Platform.isAndroid) {
        // For Android, try to get the public Downloads directory
        try {
          // Try to access the Downloads directory directly
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            // Fallback to external storage Downloads
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              directory = Directory('${externalDir.path}/Download');
            }
          }
        } catch (e) {
          // Fallback to app documents directory
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        // For other platforms, use documents directory
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Ensure directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create file
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      // Verify file was created
      if (await file.exists()) {
        return file.path;
      } else {
        throw Exception('File was not created successfully');
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Open a PDF file
  static Future<bool> openPDF(String filePath, {BuildContext? context}) async {
    try {
      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open PDF: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }
  }

  /// Show success message with open option
  static void showSuccessMessage(
    BuildContext context,
    String filePath,
    String fileName,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('PDF saved to Downloads folder!')],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Print',
          textColor: Colors.white,
          onPressed: () => openPDF(filePath, context: context),
        ),
      ),
    );
  }
}
