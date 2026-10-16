import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/animations/shimmer_loading.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Placeholder for one `VisitHistoryCard` — mirrors its exact box metrics
/// (100 map height, 14 padding, r16 border) so the swap from skeleton to
/// data doesn't shift a single pixel.
class VisitHistoryCardSkeleton extends StatelessWidget {
  const VisitHistoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appColors.border)),
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(height: 100, radius: 0),
              Padding(
                padding: EdgeInsets.all(context.rr(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 160, height: 13, radius: 6),
                    SizedBox(height: context.rh(8)),
                    const ShimmerBox(width: 200, height: 11, radius: 6),
                    SizedBox(height: context.rh(10)),
                    const ShimmerBox(width: 120, height: 11, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full loading state for the My Visits list screen.
class VisitHistoryListSkeleton extends StatelessWidget {
  const VisitHistoryListSkeleton({super.key, this.itemCount = 4});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < itemCount; i++) const VisitHistoryCardSkeleton()
      ],
    );
  }
}
