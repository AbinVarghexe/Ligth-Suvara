import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';

/// Alternative PDF download utility that ensures files go to Downloads
class DownloadsHelper {
  /// Get the Downloads directory path
  static Future<String?> getDownloadsPath() async {
    if (Platform.isAndroid) {
      // Try to get the public Downloads directory that users can see
      try {
        // Use getExternalStorageDirectory and navigate to Downloads
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Go up to the root of external storage and then to Downloads
          final rootPath = externalDir.path.split('/Android')[0];
          final downloadsPath = '$rootPath/Download';
          final downloadsDir = Directory(downloadsPath);
          
          if (await downloadsDir.exists()) {
            return downloadsPath;
          }
          
          // Try Downloads (plural)
          final downloadsPathPlural = '$rootPath/Downloads';
          final downloadsDirPlural = Directory(downloadsPathPlural);
          if (await downloadsDirPlural.exists()) {
            return downloadsPathPlural;
          }
        }
      } catch (e) {
        // Continue to next fallback
      }
      
      // Try direct paths that users can access
      final possiblePaths = [
        '/sdcard/Download',
        '/sdcard/Downloads',
        '/storage/sdcard0/Download',
        '/storage/sdcard0/Downloads',
      ];

      for (final path in possiblePaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          return path;
        }
      }
    }

    // Final fallback to app documents directory
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    } catch (e) {
      return null;
    }
  }

  /// Save PDF to Downloads folder
  static Future<String?> saveToDownloads(
    Uint8List pdfBytes,
    String fileName, {
    BuildContext? context,
  }) async {
    try {
      final downloadsPath = await getDownloadsPath();
      if (downloadsPath == null) {
        throw Exception('Could not access Downloads directory');
      }

      final directory = Directory(downloadsPath);

      // Ensure directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create file
      final file = File('$downloadsPath/$fileName');
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
            content: Text('Error saving to Downloads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  /// Show success message
  static void showDownloadSuccess(
    BuildContext context,
    String filePath,
    String fileName,
  ) {
    // Extract the directory path for display
    final directory = filePath.substring(0, filePath.lastIndexOf('/'));
    final displayPath = directory.contains('/Download') ? 'Downloads folder' : directory;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ PDF saved successfully!'),
            Text('📁 File: $fileName', style: TextStyle(fontSize: 12)),
            Text(
              '📍 Location: $displayPath',
              style: TextStyle(fontSize: 11),
            ),
            Text(
              '🔍 Full path: $filePath',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Open PDF',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await OpenFile.open(filePath);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open PDF: $e'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
