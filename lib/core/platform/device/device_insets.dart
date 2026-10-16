import 'package:flutter/material.dart';

/// Centralised access to device insets — safe area, keyboard, gesture bar,
/// home indicator — so features never reach into [MediaQuery] themselves.
///
/// ## Scope: deliberately small
///
/// This is **not** a general device/responsive abstraction, and that is a
/// decision rather than an omission:
///
/// - **Responsive sizing already has an owner.** `flutter_screenutil` is
///   configured in `app.dart` (`designSize: 390×844`) and used across the app.
///   A second breakpoint/responsive system here would compete with it, and
///   features would have to know which one to trust.
/// - **Safe area already has an owner.** `SafeArea` is used correctly in ~43
///   files. Wrapping it in a helper would add indirection without removing
///   anything — the only two places that read `padding.bottom` directly are
///   `app_coach`'s overlay and floating button, which position themselves
///   *outside* the tree's SafeArea and therefore legitimately need the raw
///   value. [safeBottom] serves exactly those cases.
///
/// What was genuinely duplicated was the keyboard inset in bottom sheets
/// (14 identical copies of `EdgeInsets.only(bottom: viewInsets.bottom)`), which
/// [AppBottomSheet] now owns via [sheetBottomInset].
///
/// ## Why an extension, not a static class
///
/// `context.deviceInsets` reads at the call site and, crucially, each getter
/// uses the scoped `MediaQuery.xOf(context)` accessors — so a widget reading
/// only [keyboard] does not rebuild when the screen *size* changes. A static
/// `DeviceHelper.of(context)` calling `MediaQuery.of(context)` would subscribe
/// every caller to every metric, which is the usual reason these helpers make
/// rebuild storms worse rather than better.
extension DeviceInsets on BuildContext {
  DeviceInsetsData get deviceInsets => DeviceInsetsData._(this);
}

class DeviceInsetsData {
  const DeviceInsetsData._(this._context);

  final BuildContext _context;

  /// Height of the on-screen keyboard, or 0 when closed.
  ///
  /// Uses `viewInsetsOf`, so only widgets that actually read this rebuild when
  /// the keyboard animates.
  double get keyboard => MediaQuery.viewInsetsOf(_context).bottom;

  bool get isKeyboardOpen => keyboard > 0;

  /// Bottom safe inset: iOS home indicator, or the Android gesture bar /
  /// 3-button navigation bar.
  ///
  /// **Already excludes the keyboard.** `MediaQuery.padding` is `viewPadding`
  /// minus `viewInsets`, so this returns 0 while the keyboard is open — the
  /// keyboard is covering the gesture bar, so there is nothing left to pad for.
  /// That is why no `max(keyboard, safeBottom)` helper exists here: the
  /// framework has already done that arithmetic, and re-doing it is how
  /// hand-rolled inset maths ends up double-counting and leaving a dead band.
  ///
  /// Prefer `SafeArea`. Reach for this only when a widget sits *outside* the
  /// safe-area subtree — an overlay, a positioned FAB — and must account for
  /// the inset itself. `app_coach`'s overlay and floating button are the two
  /// legitimate cases in this codebase.
  double get safeBottom => MediaQuery.paddingOf(_context).bottom;

  /// Top safe inset: status bar / notch / punch-hole.
  double get safeTop => MediaQuery.paddingOf(_context).top;

  /// Bottom padding for a scrollable so its final item clears the system UI.
  ///
  /// [extra] covers anything the app draws on top — a bottom nav bar, a FAB.
  double scrollBottomInset({double extra = 0}) => safeBottom + extra;

  /// Bottom padding for a modal bottom sheet's content: the keyboard height
  /// while it's open, the safe-area inset (iOS home indicator / Android
  /// gesture bar) once it's closed, plus whatever breathing room the sheet
  /// itself wants via [extra].
  ///
  /// Summing [keyboard] and [safeBottom] — rather than `max`-ing them — is
  /// safe for the same reason noted on [safeBottom]: `MediaQuery.padding`
  /// already reads 0 while the keyboard covers the gesture bar, so there's
  /// nothing left to double-count.
  ///
  /// This is the inset [AppBottomSheet] uses internally. Reach for it
  /// directly only when a sheet is built by hand outside that wrapper — e.g.
  /// [AddDepotBottomSheet]'s multi-step form, which needs its own
  /// `showModalBottomSheet` call and can't go through [AppBottomSheet].
  double sheetBottomInset({double extra = 0}) => keyboard + safeBottom + extra;

  Size get screenSize => MediaQuery.sizeOf(_context);

  bool get isLandscape =>
      MediaQuery.orientationOf(_context) == Orientation.landscape;

  /// True on tablets and unfolded foldables.
  ///
  /// 600dp is the Material 3 "medium" breakpoint and the same threshold
  /// Android uses for large-screen behaviour, so an unfolded foldable reports
  /// true here without needing a foldable-specific API (`display_features`
  /// would be required for hinge/posture awareness, which nothing needs yet —
  /// adding that dependency is a `SECURITY.md` §14 decision for when it does).
  bool get isTablet => screenSize.shortestSide >= 600;
}
