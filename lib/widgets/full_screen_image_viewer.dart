import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: heroTag != null
                  ? Hero(tag: heroTag!, child: _buildImage())
                  : _buildImage(),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // share button (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () {
                  // TODO: Implement sharing
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(imageUrl.split(',').last);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
        );
      } catch (_) {
        // Fallback to error view
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load image',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}
