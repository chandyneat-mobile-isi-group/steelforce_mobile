import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/shimmer_loading.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Directory-level loading state used while the first depot page is read: a
/// shimmer skeleton of the page itself — search bar, list selector, then
/// depot cards — laid out like the loaded screen so nothing jumps when the
/// depots arrive. Never a blank screen or a lone spinner.
class DepotLoading extends StatelessWidget {
  const DepotLoading({super.key, this.cardCount = 6});

  /// Enough to fill a phone; the list does not scroll while loading.
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'common.loading'.tr,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          // The loaded list's own header padding.
          padding: EdgeInsets.fromLTRB(
              context.rw(16), context.rh(46), context.rw(16), context.rh(16)),
          children: [
            // Search bar, then the Depots / Non-BP / Awaiting selector.
            Shimmer(
              child: Column(
                children: [
                  ShimmerBox(height: context.rh(48), radius: context.rr(14)),
                  SizedBox(height: context.rh(12)),
                  ShimmerBox(height: context.rh(44), radius: context.rr(14)),
                ],
              ),
            ),
            SizedBox(height: context.rh(12)),
            for (var i = 0; i < cardCount; i++) ...[
              if (i > 0) SizedBox(height: context.rh(12)),
              // Varied widths, so the column reads as real rows of text.
              _DepotCardSkeleton(nameWidth: context.rw(i.isEven ? 190 : 150)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One [DepotCard]'s shape: name with the status pill in the corner, the
/// address line, then territory · channel · tier beside the two actions.
/// The text bars are [Flexible]: they shrink rather than overflow where the
/// card is narrower than their scaled width.
class _DepotCardSkeleton extends StatelessWidget {
  const _DepotCardSkeleton({required this.nameWidth});

  final double nameWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final line = context.rr(6);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(16), vertical: context.rh(12)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: ShimmerBox(
                      width: nameWidth, height: context.rh(15), radius: line),
                ),
                const Spacer(),
                ShimmerBox(
                    width: context.rw(58),
                    height: context.rh(20),
                    radius: context.rr(10)),
              ],
            ),
            SizedBox(height: context.rh(8)),
            Row(
              children: [
                ShimmerBox(
                    width: context.rr(13),
                    height: context.rr(13),
                    radius: context.rr(7)),
                SizedBox(width: context.rw(4)),
                Flexible(
                  child: ShimmerBox(
                      width: context.rw(210),
                      height: context.rh(11),
                      radius: line),
                ),
              ],
            ),
            SizedBox(height: context.rh(10)),
            Row(
              children: [
                Flexible(
                  child: ShimmerBox(
                      width: context.rw(120),
                      height: context.rh(11),
                      radius: line),
                ),
                const Spacer(),
                for (final width in [64.0, 70.0]) ...[
                  SizedBox(width: context.rw(8)),
                  ShimmerBox(
                      width: context.rw(width),
                      height: context.rh(30),
                      radius: context.rr(10)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
