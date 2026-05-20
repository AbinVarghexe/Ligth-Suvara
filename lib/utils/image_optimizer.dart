import 'dart:io';
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

  /// Iteratively compress image until it's below the target size (in KB)
  static Future<File?> compressBelowLimit(
    File imageFile, {
    int targetSizeKB = 400,
  }) async {
    try {
      final originalSize = await imageFile.length();
      if (originalSize <= targetSizeKB * 1024) {
        return imageFile;
      }

      print(
        'Starting iterative compression for image of size ${originalSize ~/ 1024}KB',
      );

      // Pass 1: High quality
      File? result = await compressImage(imageFile, quality: 85);
      if (result != null && await result.length() <= targetSizeKB * 1024) {
        return result;
      }

      // Pass 2: Medium quality
      result = await compressImage(imageFile, quality: 60);
      if (result != null && await result.length() <= targetSizeKB * 1024) {
        return result;
      }

      // Pass 3: Low quality + Scale
      result = await compressImage(
        imageFile,
        quality: 40,
        minWidth: 1024,
        minHeight: 768,
      );
      if (result != null && await result.length() <= targetSizeKB * 1024) {
        return result;
      }

      // Pass 4: Very low quality + Aggressive Scale
      result = await compressImage(
        imageFile,
        quality: 25,
        minWidth: 800,
        minHeight: 600,
      );

      return result ?? imageFile; // Return compressed result, or fallback to original if compression failed
    } catch (e) {
      print('Error in iterative compression: $e');
      return imageFile; // Fallback to original
    }
  }
}
