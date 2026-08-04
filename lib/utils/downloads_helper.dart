import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';

/// Alternative PDF download utility that ensures files go to Downloads
class DownloadsHelper {
  /// Get the Downloads directory path
  static Future<String?> getDownloadsPath() async {
    if (Platform.isAndroid) {
      // 1. Try App External Files Directory (Always works on all Android devices & OEMs including Poco/MIUI without permission block)
      try {
        final extAppDir = await getExternalStorageDirectory();
        if (extAppDir != null) {
          final publicRoot = extAppDir.path.split('/Android')[0];
          final publicDownloadPath = '$publicRoot/Download';
          final publicDir = Directory(publicDownloadPath);

          // Verify if we can physically create & write to public Download dir
          try {
            if (!await publicDir.exists()) {
              await publicDir.create(recursive: true);
            }
            final testFile = File('$publicDownloadPath/.perm_test');
            await testFile.writeAsString('test');
            await testFile.delete();
            return publicDownloadPath;
          } catch (_) {
            // Android 11+ Scoped Storage restriction triggered -> return external app path guaranteed readable by system & Office apps
            return extAppDir.path;
          }
        }
      } catch (e) {
        debugPrint('Error getting external storage directory: $e');
      }

      final possiblePaths = [
        '/storage/emulated/0/Download',
        '/sdcard/Download',
      ];

      for (final path in possiblePaths) {
        final dir = Directory(path);
        try {
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return path;
        } catch (_) {}
      }
    }

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
              await OpenFilex.open(filePath);
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
