import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Image optimization utilities for better performance
class ImageOptimizer {
  /// Compress image with optimal settings for mobile
  static Future<File?> compressImage(
    File imageFile, {
    int quality = 80,
    int minWidth = 800,
    int minHeight = 600,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        final compressedFileObj = File(compressedFile.path);
        final originalSize = await imageFile.length();
        final compressedSize = await compressedFileObj.length();

        // Log compression ratio in debug mode
        if (compressedSize < originalSize) {
          final ratio = ((originalSize - compressedSize) / originalSize * 100)
              .round();
          print(
            'Image compressed by $ratio% (${originalSize ~/ 1024}KB -> ${compressedSize ~/ 1024}KB)',
          );
        }

        return compressedFileObj;
      }
    } catch (e) {
      print('Error compressing image: $e');
    }
    return null;
  }

  /// Get optimal image dimensions for different use cases
  static Map<String, int> getOptimalDimensions(String useCase) {
    switch (useCase) {
      case 'thumbnail':
        return {'width': 200, 'height': 200};
      case 'card':
        return {'width': 400, 'height': 300};
      case 'fullscreen':
        return {'width': 800, 'height': 600};
      case 'profile':
        return {'width': 300, 'height': 300};
      default:
        return {'width': 600, 'height': 400};
    }
  }

  /// Check if image file size is within acceptable limits
  static Future<bool> isImageSizeAcceptable(
    File imageFile, {
    int maxSizeKB = 500,
  }) async {
    final fileSize = await imageFile.length();
    final fileSizeKB = fileSize ~/ 1024;
    return fileSizeKB <= maxSizeKB;
  }
}
