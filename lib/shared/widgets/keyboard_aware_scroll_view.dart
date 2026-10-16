import 'package:flutter/material.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';

/// A scrollable form body that behaves correctly while the keyboard is open.
///
/// ## What this owns, and what it deliberately does not
///
/// Two things must be true for a focused field to stay visible: the scrollable
/// must be able to scroll, and its viewport must end above the keyboard.
///
/// This widget owns the **first**. The second already has an owner in every
/// context this app uses:
///
///  - **Screens** — `Scaffold` resizes for the keyboard by default
///    (`resizeToAvoidBottomInset`), which shortens the viewport for us.
///  - **Sheets** — [AppBottomSheet] applies `EdgeInsets.only(bottom: keyboard)`
///    around its child.
///
/// So this does **not** add a keyboard inset by default. Doing so would
/// double-count against those owners and leave a dead band the height of the
/// keyboard below the content — the classic symptom of two layers each "fixing"
/// the keyboard. Set [reserveKeyboardInset] only where neither owner applies,
/// i.e. a `Scaffold` that must keep `resizeToAvoidBottomInset: false` for a
/// full-bleed backdrop (the login screen is the one such case).
///
/// Once the viewport ends above the keyboard, Flutter's own
/// `EditableText` scroll-into-view brings the focused field into view without
/// any `FocusNode`/`ensureVisible` plumbing here. Hand-rolled `ensureVisible`
/// calls are what fight that built-in behaviour and cause the double-scroll
/// jump, so this deliberately adds none.
///
/// ## Why not a package
///
/// `MediaQuery.viewInsetsOf` plus a scroll view covers every case in this app,
/// so a keyboard-visibility dependency would add a plugin, a platform channel
/// and a stream subscription to re-derive a value the framework already
/// rebuilds us with.
class KeyboardAwareScrollView extends StatelessWidget {
  const KeyboardAwareScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.reserveKeyboardInset = false,
    this.physics,
  });

  final Widget child;

  /// Content padding. When [reserveKeyboardInset] is set, the keyboard height
  /// is added to this padding's bottom rather than replacing it.
  final EdgeInsets padding;

  final ScrollController? controller;

  /// Adds the live keyboard height to the bottom padding. Only for hosts that
  /// do not already inset for the keyboard — see the note above before setting
  /// this, because the usual result of setting it unnecessarily is a permanent
  /// gap under the content.
  final bool reserveKeyboardInset;

  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    // Read through the shared extension: it uses `viewInsetsOf`, so a keyboard
    // change rebuilds this and nothing else. `MediaQuery.of(context)` would
    // subscribe every caller to size, orientation and text-scale changes too.
    final keyboard = reserveKeyboardInset ? context.deviceInsets.keyboard : 0.0;

    return SingleChildScrollView(
      controller: controller,
      physics: physics,
      // Dragging the form puts the keyboard away — the one-handed escape for a
      // rep holding the phone in a warehouse aisle, and the behaviour users
      // already expect from every native form.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: padding.copyWith(bottom: padding.bottom + keyboard),
      child: child,
    );
  }
}
