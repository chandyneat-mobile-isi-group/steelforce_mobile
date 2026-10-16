import 'package:flutter/widgets.dart';

/// Window size classes, following Material 3's definitions so the breakpoints
/// match what `NavigationBar`/`NavigationRail` are designed for.
///
/// Deliberately three, not five. Every extra class is another layout to design,
/// review, and golden-test; these three are the ones that change *navigation
/// structure*, which is the decision the rest of the app actually branches on.
enum WindowSize {
  /// Phones, and any browser window narrowed to phone width.
  ///
  /// **This is the existing mobile design, unchanged.** Bottom navigation,
  /// full-width content, `flutter_screenutil` scaling against the 390×844
  /// design size. Nothing in the responsive work may alter how this renders —
  /// it is the mobile-regression baseline.
  compact,

  /// Tablets, small laptops, split-screen desktop windows.
  medium,

  /// Laptops and desktop monitors.
  expanded;

  bool get isCompact => this == WindowSize.compact;
  bool get isMedium => this == WindowSize.medium;
  bool get isExpanded => this == WindowSize.expanded;

  /// True when there is room for persistent side navigation instead of a
  /// bottom bar. The single question most call sites are really asking.
  bool get hasSideNavigation => this != WindowSize.compact;
}

/// Breakpoint thresholds, in logical pixels.
class Breakpoints {
  Breakpoints._();

  /// Below this, the layout is the untouched mobile one.
  static const double compactMax = 600;

  /// Below this, side navigation is a compact rail; above, it can be expanded.
  static const double mediumMax = 1024;

  /// Minimum width for persistent side navigation (the rail).
  ///
  /// Deliberately *above* every tablet rather than at the [mediumMax]
  /// (`expanded`) boundary. A large iPad Pro is **1024–1032pt** wide in
  /// portrait (12.9" is 1024; the M5 13" is 1032), so keying the rail off
  /// `expanded` (>= 1024) landed just past the boundary and put a sidebar on
  /// the one device class this app does not want one on. Verified on an
  /// iPad Pro 13" (M5) simulator: 2064px / 2 = 1032pt.
  ///
  /// 1440 clears every iPad — the largest is 1366–1376pt even in landscape —
  /// and the common Android tablets (a Pixel Tablet is 1280pt in landscape),
  /// while a maximised desktop browser still qualifies. The rail is a desktop
  /// affordance here; tablets use the same "My Work" grid the phone uses.
  static const double sideNavigationMin = 1440;

  /// Content is never allowed to stretch wider than this.
  ///
  /// Not an aesthetic preference: a data table or form field spanning 2560px
  /// is genuinely hard to read (the eye loses the row) and hard to click
  /// accurately. Clamping and centring is what makes the desktop layout feel
  /// designed rather than merely stretched.
  static const double contentMaxWidth = 1200;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width < compactMax) return WindowSize.compact;
    if (width < mediumMax) return WindowSize.medium;
    return WindowSize.expanded;
  }
}

/// Convenience accessors so screens read `context.windowSize` rather than
/// threading a parameter through every widget.
extension ResponsiveContext on BuildContext {
  WindowSize get windowSize => Breakpoints.of(this);

  /// Shorthand for the most common branch.
  bool get isCompactWindow => windowSize.isCompact;

  /// True only on windows wide enough to be a desktop browser — never a
  /// tablet. See [Breakpoints.sideNavigationMin] for why this is not simply
  /// `windowSize.isExpanded`.
  bool get showsSideNavigation =>
      MediaQuery.sizeOf(this).width >= Breakpoints.sideNavigationMin;

  /// Picks a value per size class, falling back down the ladder.
  ///
  /// `expanded` falls back to `medium`, which falls back to `compact`, so a
  /// caller only specifies the sizes it actually cares about:
  ///
  /// ```dart
  /// final columns = context.responsive(compact: 1, medium: 2, expanded: 3);
  /// final padding = context.responsive(compact: 16.0, expanded: 32.0);
  /// ```
  T responsive<T>({required T compact, T? medium, T? expanded}) {
    return switch (windowSize) {
      WindowSize.compact => compact,
      WindowSize.medium => medium ?? compact,
      WindowSize.expanded => expanded ?? medium ?? compact,
    };
  }
}
