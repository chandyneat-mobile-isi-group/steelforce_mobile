/// Loading placeholder for the Home "My Work" grid — same 1 + 2 tile layout
/// as MyWorkGridSection, filled with shimmer boxes.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/shimmer_loading.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/my_work/my_work_section_header.dart';

class MyWorkGridSkeleton extends StatelessWidget {
  const MyWorkGridSkeleton({super.key});

  // Style constants (design units).
  static const double _tileHeight = 120;
  static const double _tileRadius = 20;
  static const double _gap = 12;
  static const double _iconSize = 48;
  static const double _iconRadius = 24;
  static const double _labelWidth = 72;
  static const double _labelHeight = 12;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.rh(_gap),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MyWorkSectionHeader('shell.my_work'.tr, letterSpacing: 1.6),

          // Skeleton Top: Full width
          Container(
            height: context.rh(_tileHeight),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(context.rr(_tileRadius)),
            ),
            alignment: Alignment.center,
            child: _shimmerContent(context),
          ),

          SizedBox(height: context.rh(_gap)),

          // Skeleton Bottom: 2 Columns
          Row(children: [
            _skeletonCell(context),
            SizedBox(width: context.rw(_gap)),
            _skeletonCell(context)
          ]),
        ],
      ),
    );
  }

  Widget _skeletonCell(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        height: context.rh(_tileHeight),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(context.rr(_tileRadius)),
        ),
        alignment: Alignment.center,
        child: _shimmerContent(context),
      ),
    );
  }

  /// Icon disc + label bar, shimmering — identical in every tile.
  Widget _shimmerContent(BuildContext context) {
    return Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShimmerBox(
            width: context.rr(_iconSize),
            height: context.rr(_iconSize),
            borderRadius: BorderRadius.circular(context.rr(_iconRadius)),
          ),
          SizedBox(height: context.rh(_gap)),
          ShimmerBox(
            width: context.rw(_labelWidth),
            height: context.rh(_labelHeight),
          ),
        ],
      ),
    );
  }
}
