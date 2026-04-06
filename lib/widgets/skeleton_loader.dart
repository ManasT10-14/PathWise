import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/glass_card.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    this.lines = 3,
    this.hasAvatar = false,
    this.hasImage = false,
  });

  final int lines;
  final bool hasAvatar;
  final bool hasImage;

  static SkeletonLoader card() => const SkeletonLoader(lines: 3);

  static Widget list({int itemCount = 5}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < itemCount - 1 ? 12 : 0),
          child: const SkeletonLoader(lines: 2, hasAvatar: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: _SkeletonContent(
        lines: lines,
        hasAvatar: hasAvatar,
        hasImage: hasImage,
      ),
    );
  }
}

class _SkeletonContent extends StatelessWidget {
  const _SkeletonContent({
    required this.lines,
    required this.hasAvatar,
    required this.hasImage,
  });

  final int lines;
  final bool hasAvatar;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    final widthFactors = [1.0, 0.8, 0.6];
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasAvatar) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(lines, (i) {
                    final factor = i < widthFactors.length ? widthFactors[i] : 0.5;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < lines - 1 ? 8 : 0),
                      child: Container(
                        width: (screenWidth - 64) * factor,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassSkeletonCard extends StatelessWidget {
  const _GlassSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: SkeletonLoader.list(itemCount: 3),
    );
  }
}
