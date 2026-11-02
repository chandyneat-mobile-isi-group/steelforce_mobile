/// The "MY WORK" section title on Home — the ISI chevron plus a spaced
/// uppercase label. Shared by the live grid and its loading skeleton.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/brand_chevron_mark.dart';

class MyWorkSectionHeader extends StatelessWidget {
  const MyWorkSectionHeader(this.text, {super.key, this.letterSpacing = 1.6});

  // Style constants (design units).
  static const double _leftInset = 4;
  static const double _bottomGap = 12;
  static const double _markHeight = 12;
  static const double _markToTextGap = 8;

  final String text;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8) ??
        theme.colorScheme.onSurface.withValues(alpha: 0.8);

    final double headerBase = context.responsive(compact: 14.0, medium: 16.0);

    return Padding(
      padding: EdgeInsets.only(
        left: context.rw(_leftInset),
        bottom: context.rh(_bottomGap),
      ),
      child: Row(
        children: [
          BrandChevronMark(height: context.rh(_markHeight)),
          SizedBox(width: context.rw(_markToTextGap)),
          Text(
            text,
            style: TextStyle(
              fontSize: context.rsp(headerBase),
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
