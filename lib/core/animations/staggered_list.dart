import 'package:flutter/material.dart';

import 'app_animations.dart';
import 'fade_slide_transition.dart';

/// Utilities for staggering a group of widgets into view.
///
/// Use [StaggeredList.wrap] when you need the wrapped children back to place
/// them yourself (inside a Row, Wrap, or the cells of a grid), or
/// [StaggeredColumn] for a simple vertical list.
abstract final class StaggeredList {
  const StaggeredList._();

  static List<Widget> wrap(
    List<Widget> children, {
    Duration interval = AppDurations.stagger,
    Duration baseDelay = Duration.zero,
    Duration duration = AppDurations.entrance,
    double offset = 16,
    bool enabled = true,
  }) {
    return List<Widget>.generate(children.length, (i) {
      return FadeSlideIn(
        delay: baseDelay + interval * i,
        duration: duration,
        offset: offset,
        enabled: enabled,
        child: children[i],
      );
    });
  }
}

/// A [Column] whose children fade + slide in one after another.
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.interval = AppDurations.stagger,
    this.baseDelay = Duration.zero,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.spacing = 0,
    this.enabled = true,
  });

  final List<Widget> children;
  final Duration interval;
  final Duration baseDelay;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final wrapped = StaggeredList.wrap(
      children,
      interval: interval,
      baseDelay: baseDelay,
      enabled: enabled,
    );
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (int i = 0; i < wrapped.length; i++) ...[
          if (i > 0 && spacing > 0) SizedBox(height: spacing),
          wrapped[i],
        ],
      ],
    );
  }
}
