import 'package:flutter/material.dart';
import '../../../../widgets/skeleton_loader.dart';

class SkeletonEventCard extends StatelessWidget {
  const SkeletonEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: double.infinity, height: 150, borderRadius: 20),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 200, height: 18),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonLoader(width: 80, height: 12),
                    const SizedBox(width: 12),
                    SkeletonLoader(width: 100, height: 12),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonLoader(width: 18, height: 18, borderRadius: 9),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 120, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
