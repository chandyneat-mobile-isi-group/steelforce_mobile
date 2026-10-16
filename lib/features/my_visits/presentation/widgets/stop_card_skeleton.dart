import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/shimmer_loading.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Shimmer placeholder mirroring [StopCard]'s metrics so the swap from loading
/// to data doesn't shift layout. Shown while the first GPS fix / stop stream is
/// still resolving (never a blank white screen).
class StopCardSkeleton extends StatelessWidget {
  const StopCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(12)),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            context.rw(14), context.rh(14), context.rw(14), context.rh(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rr(18)),
          border: Border.all(color: colors.border),
        ),
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShimmerBox(
                      width: context.rw(62),
                      height: context.rh(40),
                      radius: context.rr(12)),
                  SizedBox(width: context.rw(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                            width: context.rw(150),
                            height: context.rh(14),
                            radius: context.rr(6)),
                        SizedBox(height: context.rh(8)),
                        ShimmerBox(
                            width: context.rw(190),
                            height: context.rh(11),
                            radius: context.rr(6)),
                      ],
                    ),
                  ),
                  SizedBox(width: context.rw(8)),
                  ShimmerBox(
                      width: context.rw(54),
                      height: context.rh(20),
                      radius: context.rr(20)),
                ],
              ),
              SizedBox(height: context.rh(12)),
              Row(
                children: [
                  ShimmerBox(
                      width: context.rw(90),
                      height: context.rh(12),
                      radius: context.rr(6)),
                  SizedBox(width: context.rw(12)),
                  ShimmerBox(
                      width: context.rw(110),
                      height: context.rh(12),
                      radius: context.rr(6)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full loading state for the Stop Dashboard — summary strip placeholder + a few
/// stop-card skeletons.
class StopDashboardSkeleton extends StatelessWidget {
  const StopDashboardSkeleton({super.key, this.itemCount = 5});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          context.rw(20), context.rh(12), context.rw(20), context.rh(20)),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          height: context.rh(96),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rr(18)),
            border: Border.all(color: colors.border),
          ),
          padding: EdgeInsets.all(context.rw(14)),
          child: Shimmer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 4; i++)
                  ShimmerBox(
                      width: context.rw(48),
                      height: context.rh(40),
                      radius: context.rr(8)),
              ],
            ),
          ),
        ),
        SizedBox(height: context.rh(16)),
        for (var i = 0; i < itemCount; i++) const StopCardSkeleton(),
      ],
    );
  }
}
