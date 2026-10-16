import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';
import 'package:steelforce/core/animations/shimmer_loading.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  static const _imageSize = 84.0;

  @override
  Widget build(BuildContext context) {
    final baseColor = context.appColors.border.withValues(alpha: 0.4);

    return GlassCard(
      padding: EdgeInsets.all(context.rr(8)),
      child: Shimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                  color: baseColor, borderRadius: BorderRadius.circular(10)),
              child: const SizedBox(width: _imageSize, height: _imageSize),
            ),
            SizedBox(width: context.rw(10)),
            Expanded(
              child: SizedBox(
                height: _imageSize,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(
                            width: 40, height: 10, radius: 4, color: baseColor),
                        SizedBox(height: context.rh(4)),
                        ShimmerBox(
                            width: double.infinity,
                            height: 13,
                            radius: 4,
                            color: baseColor),
                        SizedBox(height: context.rh(4)),
                        ShimmerBox(
                            width: 90, height: 11, radius: 4, color: baseColor),
                        SizedBox(height: context.rh(3)),
                        ShimmerBox(
                            width: 70, height: 11, radius: 4, color: baseColor),
                      ],
                    ),
                    Row(
                      children: [
                        ShimmerBox(
                            width: 46, height: 14, radius: 4, color: baseColor),
                        const Spacer(),
                        ShimmerBox(
                            width: 28, height: 28, radius: 8, color: baseColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogGridSkeleton extends StatelessWidget {
  const CatalogGridSkeleton({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          context.rw(16), context.rh(8), context.rw(16), context.rh(16)),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: context.rh(10)),
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}
