import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';

// Re-exported so a widget needs one import, not two: `context.rsp(...)` and
// `context.responsive(...)`/`context.windowSize` are used together constantly,
// and splitting them across two imports is friction with no upside.
export 'package:steelforce/core/responsive/breakpoints.dart';

/// Bridges the phone-baseline design (390×844, sized with `flutter_screenutil`)
/// to larger windows.
///
/// ## Why this exists
///
/// Above [WindowSize.compact], `app.dart` sets ScreenUtil's `designSize` to the
/// real viewport, so the scale factor becomes exactly 1.0 and `120.h` means a
/// literal 120 logical pixels. That is the right call — it stops a 1920px
/// window multiplying every padding, radius, and font by ~4.9 — but it leaves
/// phone-sized boxes and type marooned on a tablet, which is why an iPad Pro
/// renders 124pt cards and 14pt labels across a 1032pt canvas and reads as
/// small, squat, and sparse.
///
/// These helpers re-apply a *deliberate, bounded* step-up per size class:
///
/// | | boxes | type |
/// |---|---|---|
/// | compact  | 1.00 | 1.00 |
/// | medium   | 1.30 | 1.50 |
/// | expanded | 1.45 | 1.63 |
///
/// **Compact is exactly 1.0**, so every phone dimension stays bit-identical —
/// `context.rh(120)` compiles to the same value as today's `120.h`. That keeps
/// the mobile-regression baseline promised in [WindowSize.compact] intact.
///
/// ## Why type now outruns boxes
///
/// This started at 1.15/1.25 — a deliberately gentle curve, on the theory that
/// a tablet wants bigger *targets*, not bigger copy. Tested on an iPad Pro 13"
/// (1032pt) that theory was simply wrong: a 14pt label became 17.5pt on a
/// canvas 2.6x wider than the phone it was drawn for, and read as small twice
/// over in review. The type curve was raised **30%** (1.15 -> 1.50,
/// 1.25 -> 1.63) on that evidence.
///
/// Type therefore now grows *faster* than boxes. That is intentional and
/// measured, not an oversight: the cards were already judged correctly sized,
/// so only the type needed to move. The cards have room — at `expanded` a
/// 124pt card holds a 70pt icon, a 14.5pt gap, and a ~27pt line of text, so
/// roughly 110pt of a 180pt box.
///
/// The remaining guard rail is **fit**, not ratio: if a raised type scale ever
/// starts ellipsizing labels (Khmer is the first place it will show, being
/// longer than Latin and unable to break on spaces), the fix is to give the box
/// more room or allow a second line — never to shrink the type back.
///
/// ## Usage
///
/// Replace the ScreenUtil suffix with the matching helper:
///
/// ```dart
/// height: 124.h        ->  height: context.rh(124)
/// width: 48.r          ->  width: context.rr(48)
/// fontSize: 14.sp      ->  fontSize: context.rsp(14)
/// horizontal: 16.w     ->  horizontal: context.pagePadding
/// ```
extension ResponsiveSizing on BuildContext {
  /// Multiplier for boxes, icons, radii, and spacing.
  double get boxScale => responsive(compact: 1.0, medium: 1.30, expanded: 1.45);

  /// Multiplier for type.
  ///
  /// Raised 30% from the original 1.15/1.25 after on-device review — see the
  /// "Why type now outruns boxes" section in the class doc before changing it.
  double get typeScale =>
      responsive(compact: 1.0, medium: 1.50, expanded: 1.63);

  /// Responsive height. Composes with ScreenUtil so compact is unchanged.
  double rh(double v) => (v * boxScale).h;

  /// Responsive width.
  double rw(double v) => (v * boxScale).w;

  /// Responsive radius / square icon dimension.
  double rr(double v) => (v * boxScale).r;

  /// Responsive font size.
  double rsp(double v) => (v * typeScale).sp;

  /// Horizontal page gutter, per the responsive spec §12 (16 / 24 / 32).
  ///
  /// Not derived from [boxScale]: gutters are a design token with round values,
  /// and widening them on a tablet is what stops content running edge to edge.
  double get pagePadding =>
      responsive(compact: 16.0, medium: 24.0, expanded: 32.0).w;
}
