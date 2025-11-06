// lib/event_detail_skeleton.dart (or add to event_detail_screen.dart)
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class EventDetailSkeleton extends StatelessWidget {
  const EventDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // A helper widget for a single shimmer block
    Widget buildShimmerBlock({required double height, double width = double.infinity, double radius = 8}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.black, // This color is the base for the shimmer
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(), // Disable scrolling during load
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Skeleton
            buildShimmerBlock(height: 220, radius: 16),
            const SizedBox(height: 24),

            // Title Skeleton
            buildShimmerBlock(height: 30, width: 250),
            const SizedBox(height: 16),

            // Info Row Skeleton
            buildShimmerBlock(height: 40, width: double.infinity),
            const SizedBox(height: 12),
            buildShimmerBlock(height: 40, width: double.infinity),
            const Divider(height: 48, thickness: 1),

            // Description Header Skeleton
            buildShimmerBlock(height: 24, width: 200),
            const SizedBox(height: 16),

            // Description Lines Skeleton
            buildShimmerBlock(height: 16),
            const SizedBox(height: 8),
            buildShimmerBlock(height: 16),
            const SizedBox(height: 8),
            buildShimmerBlock(height: 16, width: 280),
          ],
        ),
      ),
    );
  }
}
