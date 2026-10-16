import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/animations/shimmer_loading.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Placeholder for one route tile — mirrors `RegionCard` / `_RouteTile`'s exact
/// metrics so the swap from skeleton -> data doesn't shift layout.
class RouteCardSkeleton extends StatelessWidget {
  const RouteCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(10)),
      child: Container(
        padding: EdgeInsets.all(context.rw(14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rr(16)),
          border: Border.all(color: context.appColors.border),
        ),
        child: Shimmer(
          child: Row(
            children: [
              ShimmerBox(
                  width: context.rw(40),
                  height: context.rw(40),
                  radius: context.rr(12)),
              SizedBox(width: context.rw(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(
                        width: context.rw(140),
                        height: context.rh(13),
                        radius: context.rr(6)),
                    SizedBox(height: context.rh(8)),
                    ShimmerBox(
                        width: context.rw(180),
                        height: context.rh(11),
                        radius: context.rr(6)),
                  ],
                ),
              ),
              SizedBox(width: context.rw(12)),
              ShimmerBox(
                  width: context.rw(20),
                  height: context.rw(20),
                  radius: context.rr(6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full loading state for the route dashboard — mirrors the layout of
/// [MyVisitsDashboardScreen] (Calendar section + Activity History ribbon +
/// Day Header + Route Cards) so the view transition is seamless.
class RouteDashboardSkeleton extends StatelessWidget {
  const RouteDashboardSkeleton({super.key, this.itemCount = 3});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          context.rw(20), context.rh(12), context.rw(20), context.rh(20)),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // 1. Calendar section skeleton
        Container(
          padding: EdgeInsets.all(context.rw(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rr(18)),
            border: Border.all(color: context.appColors.border),
          ),
          child: Shimmer(
            child: Row(
              children: [
                ShimmerBox(
                    width: context.rw(40),
                    height: context.rw(40),
                    radius: context.rr(12)),
                SizedBox(width: context.rw(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                          width: context.rw(160),
                          height: context.rh(14),
                          radius: context.rr(6)),
                      SizedBox(height: context.rh(6)),
                      ShimmerBox(
                          width: context.rw(100),
                          height: context.rh(10),
                          radius: context.rr(6)),
                    ],
                  ),
                ),
                ShimmerBox(
                    width: context.rw(20),
                    height: context.rw(20),
                    radius: context.rr(6)),
              ],
            ),
          ),
        ),
        SizedBox(height: context.rh(12)),

        // 2. Activity history ribbon skeleton
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(14), vertical: context.rh(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.rr(10)),
            border: Border.all(color: context.appColors.border),
          ),
          child: Shimmer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(
                    width: context.rw(130),
                    height: context.rh(13),
                    radius: context.rr(6)),
                ShimmerBox(
                    width: context.rw(14),
                    height: context.rw(14),
                    radius: context.rr(4)),
              ],
            ),
          ),
        ),
        SizedBox(height: context.rh(20)),

        // 3. Day header skeleton
        Shimmer(
          child: ShimmerBox(
              width: context.rw(80),
              height: context.rh(14),
              radius: context.rr(6)),
        ),
        SizedBox(height: context.rh(10)),

        // 4. Route card skeletons
        for (var i = 0; i < itemCount; i++) const RouteCardSkeleton(),
      ],
    );
  }
}

/// Placeholder for one inventory/shelf-count row — mirrors `_ShelfRow`'s
/// metrics so the counter list never jumps when data resolves.
class InventoryLineSkeleton extends StatelessWidget {
  const InventoryLineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: context.rh(10)),
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(14), vertical: context.rh(10)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: context.appColors.border),
      ),
      child: Shimmer(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                      width: context.rw(120),
                      height: context.rh(14),
                      radius: context.rr(6)),
                  SizedBox(height: context.rh(6)),
                  ShimmerBox(
                      width: context.rw(60),
                      height: context.rh(10),
                      radius: context.rr(6)),
                ],
              ),
            ),
            ShimmerBox(
                width: context.rw(48),
                height: context.rw(48),
                radius: context.rr(12)),
            SizedBox(width: context.rw(12)),
            ShimmerBox(
                width: context.rw(22),
                height: context.rh(18),
                radius: context.rr(6)),
            SizedBox(width: context.rw(12)),
            ShimmerBox(
                width: context.rw(48),
                height: context.rw(48),
                radius: context.rr(12)),
          ],
        ),
      ),
    );
  }
}
