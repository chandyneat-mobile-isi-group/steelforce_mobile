import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Loading placeholder for the all-drafts sheet: grabber, title bar, and two
/// row-sized blocks.
class ContinueWorkingDraftsSheetSkeleton extends StatelessWidget {
  const ContinueWorkingDraftsSheetSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final skeletonColor = scheme.onSurface.withValues(alpha: 0.12);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.rw(16), context.rh(14), context.rw(16), context.rh(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: context.rw(44),
              height: context.rh(5),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(context.rr(2.5)),
              ),
            ),
          ),
          SizedBox(height: context.rh(16)),
          Container(
            width: context.rw(160),
            height: context.rh(18),
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(context.rr(4)),
            ),
          ),
          SizedBox(height: context.rh(16)),
          ...List.generate(
            2,
            (index) => Container(
              margin: EdgeInsets.only(bottom: context.rh(10)),
              height: context.rh(70),
              decoration: BoxDecoration(
                color: skeletonColor,
                borderRadius: BorderRadius.circular(context.rr(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
