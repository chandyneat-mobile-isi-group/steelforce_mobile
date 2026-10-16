import 'package:flutter/material.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Opens a modal bottom sheet with the app's standard configuration.
///
/// Replaces ~24 call sites that each re-declared the same options — 21 repeated
/// `isScrollControlled: true`, ~17 repeated `backgroundColor: surfaceSoft`, and
/// four separate hand-rolled `RoundedRectangleBorder`s. One of those drifting
/// is how a sheet ends up with square corners or the wrong surface in dark mode.
///
/// `isScrollControlled` is always true: without it Flutter caps the sheet at
/// half the screen and the keyboard shoves the content off, which is precisely
/// the bug every caller was working around by hand.
///
/// The child is wrapped in [AppBottomSheet], so callers get keyboard insets,
/// safe area, max height and tablet width for free.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showHandle = true,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  double heightFactor = AppBottomSheet.defaultHeightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    // Width lives here, not in AppBottomSheet: showModalBottomSheet centres a
    // constrained sheet for us. Doing it in the child would need an Align,
    // which expands to fill and would force every sheet to full height.
    constraints: const BoxConstraints(maxWidth: AppBottomSheet.maxWidth),
    backgroundColor: context.appColors.surfaceSoft,
    // The sheet manages its own insets via AppBottomSheet, which needs the raw
    // keyboard value — useSafeArea here would pad the route as well and double
    // the bottom gap.
    useSafeArea: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => AppBottomSheet(
      showHandle: showHandle,
      padding: padding,
      heightFactor: heightFactor,
      child: Builder(builder: builder),
    ),
  );
}

/// Standard chrome for a modal bottom sheet: keyboard inset, safe area, max
/// height, and a readable width on large screens.
///
/// This owns the one line that was genuinely duplicated across the codebase —
/// `EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)`, which
/// appeared verbatim in 14 files — plus the `SafeArea` that always followed it.
///
/// Deliberately does **not** impose content padding ([padding] defaults to
/// zero): the existing sheets each carry their own inner padding, so adding
/// more here would double every gap. Callers keep owning their layout; this
/// owns the device.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.showHandle = true,
    this.heightFactor = defaultHeightFactor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  /// Fraction of the screen the sheet may occupy before its content scrolls.
  final double heightFactor;

  /// Leaves a strip of the page visible so the sheet still reads as modal
  /// rather than as a full-screen route the user can't dismiss.
  static const double defaultHeightFactor = 0.9;

  /// Width cap for every sheet in the app — deliberately **unbounded**, so
  /// sheets span the full window.
  ///
  /// This was 560 on the reasoning that a full-width sheet on a tablet puts its
  /// Cancel and Save buttons ~700px apart. That objection only holds when the
  /// sheet contains a *single narrow column* of fields stretched across the
  /// screen. The decision here is the other half of that trade: sheets go full
  /// width **and** their content lays out in multiple columns to fill it (see
  /// `add_depot_bottom_sheet.dart`, which shows two or three form steps at
  /// once above `compact`). A wide sheet with wide content is not stretched —
  /// it is denser, which is the point of a tablet.
  ///
  /// Kept as a named constant, not deleted: it is referenced by ~27 call sites,
  /// and one constant is what makes reversing this decision a one-line change
  /// rather than another 27-file sweep.
  static const double maxWidth = double.infinity;

  @override
  Widget build(BuildContext context) {
    final insets = context.deviceInsets;

    // In landscape there is very little vertical room, so the sheet is allowed
    // to take nearly all of it — the usual 0.9 of a short viewport leaves a
    // sheet too small to use.
    final effectiveFactor = insets.isLandscape ? 0.95 : heightFactor;

    // No Align/Center here: both expand to fill, which would force every sheet
    // to full height regardless of content. A bare ConstrainedBox lets a short
    // sheet shrink-wrap and only caps a tall one.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: insets.screenSize.height * effectiveFactor,
      ),
      child: Padding(
        // Lifts the sheet clear of the keyboard. Animates with it, because
        // viewInsets updates every frame of the keyboard transition.
        padding: EdgeInsets.only(bottom: insets.keyboard),
        child: SafeArea(
          // Complements the keyboard inset rather than duplicating it:
          // MediaQuery.padding is already 0 while the keyboard is open, so this
          // only contributes the home indicator / gesture bar when it is closed.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // stretch, or the sheet shrink-wraps to its widest child — a sheet
            // whose content happened to be narrow would collapse to a sliver
            // (with the handle alone, literally 40px wide).
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Center shields the handle from the stretch above; without it the
              // 40px pill would be forced to full width.
              if (showHandle) const Center(child: _DragHandle()),
              // Flexible, not Expanded: a short sheet stays short instead of
              // stretching to the full maxHeight, which is what makes
              // `mainAxisSize: MainAxisSize.min` children still work.
              Flexible(
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Purely decorative: dismissal is already available by dragging the sheet
      // or tapping the barrier, so announcing it adds noise.
      excludeSemantics: true,
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 2),
        decoration: BoxDecoration(
          color: context.appColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
